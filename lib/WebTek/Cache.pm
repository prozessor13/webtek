package WebTek::Cache;

# max demmelbauer
# 10-08-07
# 
# delegate the cache methods to a subcalls (e.g. Cache::Memcached)

use strict;
use WebTek::App qw( app );
use WebTek::Config qw( config );
use WebTek::Loader;
use WebTek::Exception;

our %Cache;
our %Settings;

sub import { #... when using this module, remember that
   my $class = shift;
   my @settings = @_;
   my $caller = caller;
   
   settings($caller, \@settings);
}

sub cache {
   my $config = shift || 'cache';
   unless ($Cache{app->name}{$config}) {
      if (my $class = config($config)->{'class'}) {
         WebTek::Loader->load($class);
         $Cache{app->name}{$config} = $class->new($config);                  
      } else {
         # ... dummy cache which do nothing
         $Cache{app->name}{$config} = __PACKAGE__;
      }
   }
   return $Cache{app->name}{$config};
}

sub settings {
   my $key = shift;

   if (@_) { $Settings{app->name}{$key} = shift }
   return $Settings{app->name}{$key};
}

sub key { return join ",", (app->name, @_) }

sub set { }

sub set_multi {
   my $class = shift;
   return [ map { $class->set(@$_) } @_ ];
}

sub add { }

sub get { }

sub get_multi {
   my $class = shift;
   return { map { $_ => $class->get($_) } @_ };
}

sub delete { }

sub incr { }

sub decr { }

sub find { }

1;