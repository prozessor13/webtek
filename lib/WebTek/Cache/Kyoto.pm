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
use WebTek::Logger qw( log_warning );

sub new {
   my $class = shift;
   my $config = shift || 'cache';
   eval "require IO::Socket::INET";
   my $c = config($config)->{'WebTek::Cache::Kyoto'};
   return bless { config => $c }, $class;
}

sub _connect {
   my $self = shift;
   my $addr = "$self->{config}->{host}:$self->{config}->{port}";
   $self->{socket} = IO::Socket::INET->new(
      'PeerAddr' => $addr,
      'Proto' => 'tcp',
   ) or log_warning "cannot connect to kyoto server $addr, $!";
   $self->{socket} and $self->{socket}->autoflush(1);
   return $self->{socket};
}

sub _request {
   my ($self, $method, $params, $nolog) = @_;
   delete $params->{xt} unless $params->{xt};
   $params->{DB} = $self->{config}->{db} if $self->{config}->{db};
   my $query = join "\n", map {
      APR::Base64::encode($_) . "\t" . APR::Base64::encode($params->{$_})
   } keys %$params;
   my $length = length($query);
   #... send request
   my $socket = $self->{socket} || $self->_connect || return {};
   $socket->send("POST $method HTTP/1.1\r\n");
   $socket->send("Content-Length: $length\r\n");
   $socket->send("Content-Type: text/tab-separated-values; colenc=B\r\n");
   $socket->send("\r\n$query");
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
   my ($self, $key, $value, $xt) = @_;
   my $params = { key => $key, value => nfreeze($value), xt => $xt };
   my $res = $self->_request('/rpc/set', $params);
   log_warning "kyoto set error: $key - $res->{ERROR}" if $res->{ERROR};
}

sub set_multi {
   my ($self, $params, $xt) = @_;
   my %params = map { ("_$_->[0]" => nfreeze($_->[1])) } @$params;
   $params{xt} = $xt;
   my $res = $self->_request('/rpc/set_bulk', \%params);
   log_warning "kyoto set_multi error: $res->{ERROR}" if $res->{ERROR};
}

sub get {
   my ($self, $key) = @_;
   return thaw($self->_request('/rpc/get', { key => $key })->{value});
}

sub get_multi {
   my ($self, $keys) = @_;
   my %params = map { ("_$_" => undef) } @$keys;
   my $res = $self->_request('/rpc/get_bulk', \%params, 1);
   delete $res->{num};
   my %res = map { substr($_, 1) => thaw($res->{$_}) } keys %$res;
   return \%res;
}

sub delete {
   my ($self, $key) = @_;
   my $res = $self->_request('/rpc/remove', { key => $key });
   log_warning "kyoto delete error: $key - $res->{ERROR}" if $res->{ERROR};
}

sub delete_multi {
   my ($self, $keys) = @_;
   my %params = map { ("_$_" => undef) } @$keys;
   my $res = $self->_request('/rpc/remove_bulk', \%params);
   log_warning "kyoto delete_multi error: $res->{ERROR}" if $res->{ERROR};
}

sub find {
   my ($self, $prefix, $max) = @_;
   my $params = { prefix => $prefix, max => $max || -1 };
   my $res = $self->_request('/rpc/match_prefix', $params);
   delete $res->{num};
   my @keys = map substr($_, 1), keys %$res;
   return \@keys;   
}

1;