package WebTek::Cache;

# max demmelbauer
# 10-08-07
# 
# delegate the cache methods to a subcalls (e.g. Cache::Memcached)

use strict;
use WebTek::Loader;
use WebTek::Config qw( config );

our %Cache;
our %Settings;

sub import { #... when using this module, remember that
   my ($class, @settings) = @_;
   my $caller = caller;
   
   settings($caller, \@settings);
}

sub cache {
   my $config = shift || 'cache';
   unless ($Cache{$::appname}{$config}) {
      if (my $class = config($config)->{class}) {
         WebTek::Loader->load($class);
         $Cache{$::appname}{$config} = $class->new($config);                  
      } else {
         # ... dummy cache which do nothing
         $Cache{$::appname}{$config} = __PACKAGE__;
      }
   }
   return $Cache{$::appname}{$config};
}

sub settings {
   my $key = shift;

   if (@_) { $Settings{$::appname}{$key} = shift }
   return $Settings{$::appname}{$key};
}

# ----------------------------------------------------------------------------
# cache interface
# ----------------------------------------------------------------------------

sub key { join ",", ($::appname, @_) }

sub set { }

sub set_multi { my $class = shift; [ map { $class->set(@$_) } @_ ] }

sub add { }

sub get { }

sub get_multi { my $class = shift; { map { $_ => $class->get($_) } @_ } }

sub delete { }

sub incr { }

sub decr { }

sub find { }

1;