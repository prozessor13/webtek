package WebTek::Cache::Memcached;

# max demmelbauer
# 10-08-07
#
# use memcached as cache for webtek: http://www.danga.com/memcached

use strict;
use WebTek::Config qw( config );
use Encode qw( _utf8_on encode_utf8 );
use Digest::MD5 qw( md5_hex );

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
   my $c = $Loaded->new(config('cache')->{'WebTek::Cache::Memcached'});
   return bless \$c, shift;
}

sub set {
   my ($self, $key) = (shift, shift);
   return $$self->set(md5_hex(encode_utf8($key)), @_);
}

sub add {
   my ($self, $key) = (shift, shift);
   return $$self->add(md5_hex(encode_utf8($key)), @_);
}

sub get {
   my ($self, $key) = (shift, shift);
   my $string = $$self->get(md5_hex(encode_utf8($key)));
   _utf8_on($string);
   return $string;
}

sub delete {
   my ($self, $key) = (shift, shift);
   return $$self->delete(md5_hex(encode_utf8($key)));
}

1;