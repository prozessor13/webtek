package WebTek::Util;

# max demmelbauer
# 14-02-06
#
# some utilities
# INFO! this code is not much readable for performace reasons ;-)

use IO::Socket::INET;
use WebTek::Exception;
use Sub::Identify qw( sub_name );
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );
use WebTek::Export qw( r stash slurp assert make_method make_accessor );

my $R;      # global variable for the Apache2::RequestRec
my $Stash;  # global stash

sub r { $R = $_[0] if @_; $R }

sub stash { $Stash = $_[0] if @_; $Stash }

sub assert { WebTek::Exception::Assert->throw($_[1], caller) unless $_[0] }

# ---------------------------------------------------------------------------
# file utils
# ---------------------------------------------------------------------------

sub slurp {
   my $file = shift;
   my $is_binary_file = shift;

   my $enc = ($is_binary_file ? ":raw" : ":utf8");   
   
   open(FILE, "<".$enc, $file) or throw "cannot slurp file '$file': $!";
   my @lines = <FILE>;
   close(FILE);
   return join('', @lines);
}

sub write {
   my ($file, @content) = @_;
   
   open(FILE, ">:utf8", $file) or throw "cannot write file '$file': $!";
   print FILE @content;
   close(FILE);
   return;
}

sub copy {
   my ($src, $dest) = @_;
   
   open(SRC, "<:raw", $src) or throw "cannot read file '$src': $!";
   open(DEST, ">:raw", $dest) or throw "cannot write file '$dest': $!";
   while(<SRC>) { print DEST }
   close(DEST);
   close(SRC);
}

sub find {
   my %params = @_;
   
   my $dir = delete $params{'dir'};
   assert $dir, "find: no dir defined!";

   if ($^O ne "MSWin32") { 
      my $cmd = "find -L $dir " . join " ", map "-$_ '$params{$_}'", keys %params;
      return map { s/\\/\//g; chop; $_ } `$cmd`;
   }
   
   sub aux {
      my $path = shift;
      my $params = shift;
      
      if (-f $path) {
         if ($params->{'name'} =~ /^\*\.(\w+)$/) {
            return () if ($path !~ /$1$/);
         }
         return ($path);
      } elsif (-d $path) {
         opendir my ($handle), $path or die "Error in opening dir '$path': $!";
         my @result = ();
         while(my $filename = readdir($handle)) {
            next if ($filename =~ /^\.+$/);
            push @result, aux($path . "/" . $filename, $params);
         }
         closedir($handle);
         return @result;
      } else {
         return ();
      }
   }
   
   return aux($dir, \%params);
}

# ---------------------------------------------------------------------------
# method utils
# ---------------------------------------------------------------------------

sub make_method {
   my ($class, $method, $sub, @attrs) = @_;
   $sub ||= sub { $_[0]->{$method} = $_[1] if @_ > 1; $_[0]->{$method} };
   *{"$class\::$method"} = $sub;
   WebTek::Attributes::MODIFY_CODE_ATTRIBUTES($class, $sub, @attrs) if @attrs;
}

sub may_make_method {
   my ($class, $method, $sub, @attrs) = @_;
   return if defined &{"$class\::$method"};
   make_method($class, $method, $sub, @attrs);
}

sub make_accessor {
   my $caller = caller;
   my ($method, @args) = @_;
   make_method($caller, $method, undef, @args);
}

sub subname_for_coderef {
   my ($class, $coderef) = @_;
   
   my $name = sub_name $coderef;
   return $name eq '__ANON__' ? undef : $name;
}

1;