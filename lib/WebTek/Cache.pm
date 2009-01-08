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

our $Cache;
our $Settings = {};

sub import { #... when using this module, remember that
   my $class = shift;
   my @settings = @_;
   my $caller = caller;
   
   settings($caller, \@settings);
}

sub cache {
   unless ($Cache) {
      if (my $class = config('cache')->{'class'}) {
         WebTek::Loader->load($class);
         $Cache = $class->new;                  
      } else {
         $Cache = __PACKAGE__;
      }
   }
   return $Cache;
}

sub settings {
   my $key = shift;

   if (@_) { $Settings->{$key} = shift }
   return $Settings->{$key};
}

sub key { return join ",", (app->name, @_) }

sub set { }

sub add { }

sub get { }

sub delete { }

1;