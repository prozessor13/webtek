package WebTek::Util::File;

# max wukits
# 11-02-09
#
# some file utils

use strict;
use WebTek::Export qw( slurp write copy find );

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
