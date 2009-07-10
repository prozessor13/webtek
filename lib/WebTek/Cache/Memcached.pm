package WebTek::Cache::Memcached;

# max demmelbauer
# 10-08-07
#
# use memcached as cache for webtek: http://www.danga.com/memcached

use strict;
use WebTek::Exception;
use WebTek::Config qw( config );
use Encode qw( _utf8_on encode_utf8 );
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

sub new {
   my $class = shift;
   my $config = shift || 'cache';
   my $c = $Loaded->new(config($config)->{'WebTek::Cache::Memcached'});
   return bless \$c, $class;
}

sub set {
   my ($self, $key, @set) = @_;
   return $$self->set(md5_hex(encode_utf8($key)), @set)
      or log_warning("WebTek::Cache::Memcached cannot save key: $key");
}

sub set_multi {
   my ($self, @sets) = @_;
   my @sets2 = map [ md5_hex(encode_utf8($_->[0])), $_->[1] ], @sets;
   my @r = $$self->set_multi(@sets2);
   if (my @e = grep $_, map { @r[$_] ? undef : $sets[$_][0] } 0 .. $#r) {
      log_warning("WebTek::Cache::Memcached cannot save keys: @e");
   }
   return \@r;
}

sub add {
   my ($self, $key, @add) = @_;
   return $$self->add(md5_hex(encode_utf8($key)), @add);
}

sub get {
   my ($self, $key) = @_;
   my $string = $$self->get(md5_hex(encode_utf8($key)));
   _utf8_on($string);
   return $string;
}

sub get_multi {
   my ($self, @keys) = @_;
   my %keys = map { md5_hex(encode_utf8($_)) => $_ } @keys;
   my $result = $$self->get_multi(keys %keys);
   _utf8_on($result->{$_}) foreach keys %$result;
   return { map { $keys{$_} => $result->{$_} } keys %$result };
}

sub delete {
   my ($self, $key) = @_;
   return $$self->delete(md5_hex(encode_utf8($key)));
}

sub incr {
   my ($self, $key, @incr) = @_;
   return $$self->incr(md5_hex(encode_utf8($key)), @incr);
}

sub decr {
   my ($self, $key, @decr) = @_;
   return $$self->decr(md5_hex(encode_utf8($key)), @decr);
}

sub find { throw "method not supportet" }

1;