package WebTek::Session::Memcached;

# max demmelbauer
# 22-09-08
#
# store session in memcache

use strict;
use WebTek::Globals;
use WebTek::Util qw( make_accessor );
use base qw( WebTek::Session );

make_accessor('id', 'Macro');
make_accessor('data', 'Macro');
make_accessor('create_time', 'Macro');
make_accessor('ip_address', 'Macro');

sub _init { }

sub _cache {
   my $config = config->{'session'}->{'cache-config'};
   return cache($config);
}

sub new {
   my ($class, %params) = @_;
   
   my $self = $class->SUPER::new;
   $self->id($params{'id'});
   $self->data($params{'data'});
   $self->create_time($params{'create_time'});
   $self->ip_address($params{'ip_address'});
   return $self;
}

sub find_one {
   my ($self, %params) = @_;
   
   my $key = WebTek::Cache::key($params{'id'}, $params{'ip_address'});
   return $self->_cache->get($key);
}

sub save {
   my ($self, %params) = @_;
   
   my $time = config->{'session'}->{'expiry-time'};
   my $key = WebTek::Cache::key($self->id, $self->ip_address);
   $self->_cache->set($key, $self, $time);
}

1;
