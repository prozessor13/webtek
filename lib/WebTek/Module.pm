package WebTek::Module;

# max demmelbauer
# 3-01-07
#
# loads an WebTek app Module (composed from core and modules directories)

use strict;
use WebTek::App qw( app );
use WebTek::Util qw( slurp );
use WebTek::Event qw( event );
use WebTek::Logger qw( ALL );

our %Loaded = ();

sub load {
   my ($class, $package) = @_;
   
   log_debug("load perl module $package");
   
   #... remove all events
   event->remove_all_on_object($package) if $Loaded{$package};

   #... remove old code (code stolen from Class::Unload)
   {
      no strict 'refs';
      @{$package . '::ISA'} = ();
      my $symtab = $package . '::';
      foreach my $symbol (keys %$symtab) {
         next if substr($symbol, -2, 2) eq '::';
         delete $symtab->{$symbol};
      }
   }
   
   #... create filename from packagename
   my $fname = $package;
   $fname =~ s|\w+/||;
   $fname =~ s|::|/|g;
   $fname .= ".pm";
   my $incname = $fname;
   $fname =~ s/^.*?\///;

   #... find all necesarry files
   my @files = grep -f, map "$_/$fname", @{app->dirs};

   #... (re)load code
   if (@files) {
      #... load module files
      foreach my $file (@files) {
         log_debug("load perl module file $file");
         $class->do($file, $package);
      }

      #... may init module
      $package->_init
         if $package->can('_INIT')
         and $package->_INIT
         and $package->can('_init');
   }

   #... remember that the module is already loaded
   $Loaded{$package} = scalar @files;
   $INC{$incname} = $files[0];
   
   event->notify('module-loaded', $package);
}

sub require {
   my ($class, $package) = @_;
   
   return $Loaded{$package} if exists $Loaded{$package};
   return $class->load($package);
}

sub source_filter {
   my ($class, $source) = @_;
   
   #... replace constucts like use app->Model->X to use MyApp::Model::X
   $source =~ s/(^|\W)app(\:\:[\w\:]+)/$1 . app->class_prefix . $2/emg;
   #... replace sub($x) { ... } to sub { my ($self, $x) = @_; ... }
   $source =~ s/(^|[^\w'"\$\@\%])(class\s+)?method(\s+[^\W\d]\w*)?(\((.*?)\))?(.*?\{)/
      $2 ? "$1sub$3$6 my (\$class, $5) = \@_; \$class = ref \$class || \$class;"
         : "$1sub$3$6 my (\$self, $5) = \@_;"
   /eg;
   return $source;
}

sub do {
   my ($_class, $_file, $_package) = @_;
   #... read code from disk
   my $_code = $_class->source_filter(slurp($_file));
   #... check if code is in an package
   $_package ||= 'main';
   #... eval code
   eval qq{
package $_package;
use strict;
use WebTek::Globals;
#line 1 "$_file"
$_code;
1;
   } or die "WebTek::Module: cannot load file '$_file', details $@";   
}

1;
