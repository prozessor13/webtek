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

sub new {
   my ($class, %params) = @_;
   
   return bless \%params, $class;
}

sub find_one {
   my ($self, %params) = @_;
   
   my $key = WebTek::Cache::key($params{'id'}, $params{'ip_address'});
   return cache->get($key);
}

sub save {
   my ($self, %params) = @_;
   
   my $time = config->{'session'}->{'expiry-time'};
   my $key = WebTek::Cache::key($self->id, $self->ip_address);
   cache->set($key, $self, $time);
}

1;