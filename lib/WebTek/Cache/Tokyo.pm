package WebTek::Cache::Tokyo;

# max demmelbauer
# 02-07-09
#
# use tokyo as cache for webtek: http://tokyocabinet.sourceforge.net

use strict;
use Storable qw( );
use Encode qw( encode decode );
use WebTek::Config qw( config );
use WebTek::Logger qw( log_error );
use WebTek::Data::Struct qw( struct );

sub new {
   my $class = shift;
   my $config = config(shift || 'cache')->{$class};
   my $timeout = $config->{'timeout'} || 10;
   eval "require TokyoTyrant";
   my $rdb = TokyoTyrant::RDB->new;
   log_error $rdb->errmsg($rdb->ecode)
      unless $rdb->open($config->{'host'}, $config->{'port'});
   return bless \$rdb, $class;
}

sub set {
   my ($self, $key, $value) = @_;
   $key = encode("UTF-8", $key);
   my $ref = ref $value ? $value : \$value;
   log_error $$self->errmsg($$self->ecode)
      unless my $return = $$self->put($key, Storable::nfreeze($ref));
   return $return;
}

sub add {
   my ($self, $key, $value) = @_;
   $key = encode("UTF-8", $key);
   log_error $$self->errmsg($$self->ecode)
      unless my $return = $$self->putkeep($key, Storable::nfreeze($value));
   return $return;
}

sub get {
   my ($self, $key) = @_;
   $key = encode("UTF-8", $key);
   return Storable::thaw($$self->get($key));
}

sub get_multi {
   my ($self, $keys) = @_;
   my %hash = map {
      my $k = encode("UTF-8", $_);
      $k => undef;
   } @$keys;
   log_error $$self->errmsg($$self->ecode) if $$self->mget(\%hash) eq -1;
   foreach (keys %hash) {
      my $k = decode("UTF-8", $_);
      $hash{$k} = Storable::thaw($hash{$_});
   }
   return \%hash;
}

sub delete {
   my ($self, $key) = @_;
   $key = encode("UTF-8", $key);
   log_error $$self->errmsg($$self->ecode)
      unless my $return = $$self->out($key);
   return $return;
}

sub incr {
   my ($self, $key, $incr) = @_;
   $key = encode("UTF-8", $key);
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
   $prefix = encode("UTF-8", $prefix);
   return $$self->fwmkeys($prefix, $max);
}

1;