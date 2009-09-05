package WebTek::Cache::Tokyo;

# max demmelbauer
# 02-07-09
#
# use tokyo as cache for webtek: http://tokyocabinet.sourceforge.net

use strict;
use Storable qw( );
use Encode qw( _utf8_off );
use WebTek::Config qw( config );
use WebTek::Logger qw( log_error );
use WebTek::Data::Struct qw( struct );
use Encode qw( _utf8_on );

sub new {
   my $class = shift;
   my $config = config(shift || 'cache')->{$class};
   eval "require TokyoTyrant";
   my $rdb = TokyoTyrant::RDB->new;
   log_error $rdb->errmsg($rdb->ecode)
      unless $rdb->open($config->{'host'}, $config->{'port'});
   return bless \$rdb, $class;
}

sub set {
   my ($self, $key, $value) = @_;
   _utf8_off($key);
   my $ref = ref $value ? $value : \$value;
   log_error $$self->errmsg($$self->ecode)
      unless my $return = $$self->put($key, Storable::nfreeze($ref));
   return $return;
}

sub add {
   my ($self, $key, $value) = @_;
   _utf8_off($key);
   log_error $$self->errmsg($$self->ecode)
      unless my $return = $$self->putkeep($key, Storable::nfreeze($value));
   return $return;
}

sub get {
   my ($self, $key) = @_;
   _utf8_off($key);
   my $value = Storable::thaw($$self->get($key));
   if (ref $value eq 'SCALAR') {
      $value = $$value; 
      _utf8_on($value);      
   }
   return $value;
}

sub get_multi {
   my ($self, @keys) = @_;
   my %hash = map { _utf8_off($_); $_ => undef } @keys;
   log_error $$self->errmsg($$self->ecode) if $$self->mget(\%hash) eq -1;
   $hash{$_} = Storable::thaw($hash{$_}) foreach (keys %hash);
   return \%hash;
}

sub delete {
   my ($self, $key) = @_;
   _utf8_off($key);
   log_error $$self->errmsg($$self->ecode)
      unless my $return = $$self->out($key);
   return $return;
}

sub incr {
   my ($self, $key, $incr) = @_;
   _utf8_off($key);
   log_error $$self->errmsg($$self->ecode)
      unless defined(my $value = $$self->addint($key, $incr));
   return $value;
}

sub decr {
   my ($self, $key, $decr) = @_;
   return $self->incr($key, -$decr);
}

sub find {
   my ($self, $prefix, $max) = @_;
   _utf8_off($prefix);
   return $$self->fwmkeys($prefix, $max);
}

1;