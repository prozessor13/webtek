package WebTek::Config;

# max demmelbauer
# 14-02-06
#
# return config settings from config-files

use strict;
use WebTek::App qw( app );
use WebTek::Util qw( assert );
use WebTek::Logger qw( ALL );
use WebTek::Exception;
use WebTek::Data::Struct  qw( struct );
use WebTek::Util::File qw( slurp );
use WebTek::Export qw( config );

our %Config = ();

sub config {
   my $name = shift || 'webtek'; 
   my $config = $Config{app->name} or throw "Config not initialized!";
   my $result = $config->{$name};
   unless (defined($result)) { throw "no config found for name '$name.config'";}
   return $result;
}

sub load {
   my $class = shift;
   my $name = shift;

   my @files;
   my $config = {};
   
   #... find all necessary files
   foreach my $env (('', map { ".$_" } @{app->env})) {
      push @files, grep -f, map "$_/config/$name$env.config", @{app->dirs};
   }

   #... load and merge all together
   foreach my $file (@files) {
      WebTek::Logger::log_debug("load config $name: '$file'");
      my $content = WebTek::Module->source_filter(slurp($file));
      my $c = eval $content
         or throw "Config: cannot load $file, details: $!, $@";
      $config = _merge($config, $c);
   }

   #... store config
   $Config{app->name}->{$name} = WebTek::Data::Struct->new($config);
}

#... this code is stolen form Catalyst::Utils::merge_hashes
sub _merge {
   my ($left, $right) = @_;

   return $left unless defined $right;
    
   my %merged = %$left;
   for my $key (keys %$right) {
      my $right_ref = 'HASH' eq (ref $right->{$key});
      my $left_ref = 'HASH' eq (exists $left->{$key} && ref $left->{$key});
      if ($right_ref and $left_ref) {
         $merged{$key} = _merge($left->{$key}, $right->{$key});
      } else {
         $merged{$key} = $right->{$key};
      }
   }
 
   return \%merged;
}

1;
