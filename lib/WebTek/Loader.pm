package WebTek::Loader;

# max demmelbauer
# 20-03-06
#
# reload and load modules

use strict;
use WebTek::App qw( app );
use WebTek::Event qw( event );
use WebTek::Config qw( config );
use WebTek::Logger qw( ALL );
use WebTek::Timing qw( timer_start timer_end );
use WebTek::Module;
use WebTek::Static;
use WebTek::Message;
use WebTek::Exception;

our %Files = ();

sub reset { $Files{app->name} = {} }

sub init {
   my ($class, $safe) = @_;    # may init modules safe (no die on error)	

   #... register code-reload event
   event->register(
      'name' => 'request-begin',
      'priority' => 1,
      'method' => sub {
         WebTek::Util::stash({});
         if (config->{'code-reload'}) {
            timer_start('reload code');
            reload();
            timer_end('reload code');
         }
      },
   );

   #... replace require to load WebTek Modules correctly
   my $prefix = app->class_prefix;
   *CORE::GLOBAL::require = sub {
      my $package = shift;
      my ($pkg, $ret) = ($package, undef);
      if ($pkg =~ /^$prefix/) {
         $pkg =~ s/\//::/g;
         $pkg =~ s/.pm$//;
         $ret = WebTek::Module->require($pkg);
      } else {
         $ret = eval { CORE::require($package); 1 } or die $@;
      }
      return $ret;
   };
   
   #... load code
   WebTek::Config->load('webtek');
   my $files = files();
   load_configs($files, $safe);
   load_messages($files, $safe);

   WebTek::Timing->_init;
   WebTek::DB->_init;
   WebTek::Page->_init;

   my $session_class = config->{'session'}->{'class'};
   load($class, $session_class);
   $session_class->_init;

   load_perl_modules($files, $safe);
   merge_static_files($files, $safe);
}

sub reload {
   my ($class, $safe) = @_;    # may init modules safe (no die on error)	

   my $files = files();
   load_configs($files, $safe);
   load_messages($files, $safe);
   load_perl_modules($files, $safe);
   merge_static_files($files, $safe);   
}

sub files {
   my $ignore = config->{'file-ignore-pattern'};
   my $files = $Files{app->name} ||= {};
   
   sub _files {
      my ($dir, $files) = @_;
      my ($fh, @files);
      opendir $fh, $dir || die "cannot open dir $dir: $!";
      foreach my $f (readdir $fh) {
         next if $f =~ /^\.+$/ or $ignore and $f =~ /$ignore/;
         my $file = "$dir/$f";
         #$file = readlink $file while -l $file; # follow symlinks
         if (-f $file) {
            my $mtime = (stat $file)[9];
            if ($mtime > $files->{$file}) {
               $files->{$file} = $mtime;
               push @files, $file;
            }
         } elsif (-d $file) {
            push @files, @{_files($file, $files)};
         }
      }
      
      return \@files;
   }
   
   return _files(app->dir, $files);
}

sub load_configs {
   my ($files, $safe) = @_;
   my @loaded;
   foreach my $dir (grep -d, map "$_/config", @{app->dirs}) {
      foreach my $file (@$files) {
         next unless $file =~ /^$dir\/([^\/]+?)(\.([^\/]+))?\.config$/;
         my ($name, $env) = ($1, $3);
         next if grep { $name eq $_ } @loaded;
         next if $env and not grep { $_ eq $env } @{app->env};
         WebTek::Config->load($name); 
         push @loaded, $name;
      }
   }
}

sub load_messages {
   my ($files, $safe) = @_;
   my @loaded;
   foreach my $dir (grep -d, map "$_/messages", @{app->dirs}) {
      foreach my $file (@$files) {
         next unless $file =~ /^$dir\/(\w\w)(\.([^\/]+))?\.po$/;
         my ($name, $env) = ($1, $3);
         next if grep { $name eq $_ } @loaded;
         next if $env and not grep { $_ eq $env } @{app->env};
         WebTek::Message->load($name);
         push @loaded, $name;
      }
   }
}

sub load_perl_modules {
   my ($files, $safe) = @_;
   foreach my $dir (@{app->dirs}) {
      foreach my $file (@$files) {
         next unless $file =~ /$dir\/(([A-Z]\w+\/)+[A-Z]\w*).pm$/;
         #... create modulename from filename
         my $module = $1;
         $module =~ s|/|::|g;
         #... (safe) load module
         eval { WebTek::Module->load(app->class_prefix . '::' . $module) };
         if (my $e = $@) { $safe ? log_error($e) : log_fatal($e) }
      }
   }
}

sub merge_static_files {
   my ($files, $safe) = @_;
   #... check if there is something to do
   my $c = config->{'static'};
   return if exists $c->{'merge'} and not $c->{'merge'};
   #... merge changed static files
   my %loaded;
   my ($static, $f) = ($c->{'dir'}, $Files{app->name});
   foreach my $dir (grep -d, map "$_/static", @{app->dirs}) {
      foreach my $file (@$files) {
         next unless $file =~ /^$dir\/(.+)$/;
         my $name = $1;
         next if $loaded{$name};
         #... check modifytime of the file in static dir
         $f->{"$static/$name"} ||= (stat "$static/$name")[9];
         next if $f->{"$static/$name"} and $f->{"$static/$name"} >= $f->{$file};
         #... merge static file
         WebTek::Static->merge_static_file($name);
         $f->{"$static/$name"} = (stat "$static/$name")[9];
         $loaded{$name} = 1;
      }
   }
}

sub load {
   my ($class, $package) = @_;

   eval "require $package; 1" or throw "cannot load '$package', details $@";   
}

1;
