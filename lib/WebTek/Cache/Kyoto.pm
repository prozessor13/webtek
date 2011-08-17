package WebTek::Cache::Kyoto;

# max demmelbauer
# 01-05-11
#
# use kyoto as cache for webtek: http://fallabs.com/kyototycoon/

use strict;
use APR::Base64;
use Storable qw( nfreeze thaw );
use WebTek::Config qw( config );
use WebTek::Filter qw( decode_url );
use WebTek::Logger qw( log_error );

sub new {
   my $class = shift;
   my $config = shift || 'cache';
   eval "require IO::Socket::INET";
   my $c = config($config)->{'WebTek::Cache::Kyoto'};
   return bless { config => $c }, $class;
}

sub _connect {
   my $self = shift;
   my $addr = "$self->{config}{host}:$self->{config}{port}";
   $self->{socket} = IO::Socket::INET->new(
      'PeerAddr' => $addr,
      'Proto' => 'tcp',
   ) or log_error "cannot connect to kyoto server $addr, $!";
   $self->{socket} and $self->{socket}->autoflush(1);
   return $self->{socket};
}

sub _request {
   my ($self, $method, $params) = @_;
   delete $params->{xt} unless $params->{xt};
   delete $params->{DB} unless $params->{DB};
   my $query = join "\n", map {
      APR::Base64::encode($_) . "\t" . APR::Base64::encode($params->{$_})
   } keys %$params;
   my $length = length($query);
   #... send request
   my $socket = $self->{socket} || $self->_connect
      || return { ERROR => 'cannot connect to server' };
   $socket->send("POST $method HTTP/1.1\r\n"
      . "Content-Length: $length\r\n"
      . "Content-Type: text/tab-separated-values; colenc=B\r\n\r\n"
      . $query
   );
   my ($len, $content, $colenc, %decoded, $k, $v);
   while ((my $line = $socket->getline) ne "\r\n") {
      $len = $1 if $line =~ /Content-Length: (\d+)/;
      $colenc = $1 if $line =~ /colenc=(\w+)/;
      #... check if connected
      unless ($line) { delete $self->{socket}; return {} }
   }
   $self->{socket}->read($content, $len);
   my @c = map { ($k, $v) = split "\t"; ($k, $v) } split "\n", $content;
   if ($colenc eq 'B') { %decoded = map APR::Base64::decode($_), @c }
   elsif ($colenc eq 'U') { %decoded = map decode_url(0, $_), @c }
   else { %decoded = @c }
   return \%decoded;
}

sub set {
   my ($self, $key, $value, %p) = @_;
   %p = ( %p, key => $key, value => nfreeze($value));
   my $res = $self->_request('/rpc/set', \%p);
   log_error "kyoto set error: $key - $res->{ERROR}" if $res->{ERROR};
   return $res->{ERROR} ? 0 : 1;
}

sub set_multi {
   my ($self, $data, %p) = @_;
   %p = ( %p, map { ("_$_->[0]" => nfreeze($_->[1])) } @$data );
   my $res = $self->_request('/rpc/set_bulk', \%p);
   log_error "kyoto set_multi error: $res->{ERROR}" if $res->{ERROR};
   return $res->{ERROR} ? 0 : 1;
}

sub get {
   my ($self, $key, %p) = @_;
   return thaw($self->_request('/rpc/get', { %p, key => $key })->{value});
}

sub get_multi {
   my ($self, $keys, %p) = @_;
   %p = ( %p, map { ("_$_" => undef) } @$keys );
   my $res = $self->_request('/rpc/get_bulk', \%p);
   delete $res->{num}; delete $res->{ERROR};
   my %res = map { substr($_, 1) => thaw($res->{$_}) } keys %$res;
   return \%res;
}

sub delete {
   my ($self, $key, %p) = @_;
   my $res = $self->_request('/rpc/remove', { %p, key => $key });
   log_error "kyoto delete error: $key - $res->{ERROR}" if $res->{ERROR};
   return $res->{ERROR} ? 0 : 1;
}

sub delete_multi {
   my ($self, $keys, %p) = @_;
   %p = ( %p, map { ("_$_" => undef) } @$keys );
   my $res = $self->_request('/rpc/remove_bulk', \%p);
   log_error "kyoto delete_multi error: $res->{ERROR}" if $res->{ERROR};
   return $res->{ERROR} ? 0 : 1;
}

sub find {
   my ($self, $prefix, %p) = @_;
   %p = ( %p, prefix => $prefix, max => $p{max} || -1 );
   my $res = $self->_request('/rpc/match_prefix', \%p);
   delete $res->{num};
   my @keys = map substr($_, 1), keys %$res;
   return \@keys;   
}

1;