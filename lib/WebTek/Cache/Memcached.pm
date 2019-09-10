package WebTek::Cache::Memcached;

# max demmelbauer
# 10-08-07
#
# use memcached as cache for webtek: http://www.danga.com/memcached

use strict;
use WebTek::Exception;
use WebTek::Config qw( config );
use Encode qw( encode_utf8 decode_utf8 );
use Digest::MD5 qw( md5_hex );
use WebTek::Logger qw( log_warning );

our $Loaded;

BEGIN {
   if (eval "use Cache::Memcached::Fast (); 1") {
      $Loaded = "Cache::Memcached::Fast";
   } elsif (eval "use Cache::Memcached (); 1") {
      $Loaded = "Cache::Memcached";
   } else {
      die("Please install Cache::Memcached::Fast or Cache::Memcached");
   }
}

sub _key { md5_hex(encode_utf8($_[0])) }

sub _set { ref $_[0] ? $_[0] : encode_utf8($_[0]) }

sub _get { ref $_[0] ? $_[0] : decode_utf8($_[0]) }

sub new {
   my $class = shift;
   my $config = shift || 'cache';
   my $c = $Loaded->new(config($config)->{'WebTek::Cache::Memcached'});
   return bless \$c, $class;
}

sub set {
   my ($self, $key, $set, $time) = @_;
   return $$self->set(_key($key), _set($set), $time)
      or log_warning("WebTek::Cache::Memcached cannot save key: $key");
}

sub set_multi {
   my ($self, $sets) = @_;
   my @sets2 = map [ _key($_->[0]), _set($_->[1]) ], @$sets;
   my @r = $$self->set_multi(@sets2);
   if (my @e = grep $_, map { @r[$_] ? undef : $sets->[$_][0] } 0 .. $#r) {
      log_warning("WebTek::Cache::Memcached cannot save keys: @e");
   }
   return \@r;
}

sub add {
   my ($self, $key, $add, $time) = @_;
   return $$self->add(_key($key), _set($add), $time);
}

sub get {
   my ($self, $key) = @_;
   return _get($$self->get(_key($key)));
}

sub get_multi {
   my ($self, $keys) = @_;
   my %keys = map { _key($_) => $_ } @$keys;
   my $result = $$self->get_multi(keys %keys);
   $result->{$_} = _get($result->{$_}) foreach keys %$result;
   return { map { $keys{$_} => $result->{$_} } keys %$result };
}

sub delete {
   my ($self, $key) = @_;
   return $$self->delete(_key($key));
}

sub delete_multi {
   my ($self, $keys) = @_;
   return { map { $_ => $self->delete($_) } @$keys };
}

sub incr {
   my ($self, $key, @incr) = @_;
   return $$self->incr(_key($key), @incr);
}

sub decr {
   my ($self, $key, @decr) = @_;
   return $$self->decr(_key($key), @decr);
}

1;
