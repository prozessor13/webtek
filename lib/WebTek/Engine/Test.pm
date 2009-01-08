package WebTek::Engine::Test;

use strict;
use WebTek::Logger;
use WebTek::Config qw(config );
use WebTek::Request qw( request );

sub prepare {
   my ($self, %params) = @_;
   
   #... prepare params
   my $params = $params{'params'};
   foreach my $key (keys %$params) {
      $params->{$key} = [$params->{$key}] if ref $params->{$key} ne 'ARRAY';
   }
   
   #... prepare request
   WebTek::Request->init;
   request->cookies($params{'cookies'} || {});
   request->params($params);
   request->hostname($params{'hostname'} || 'localhost');
   request->remote_ip($params{'remote_ip'} || '127.0.0.1');
   request->method(uc($params{'method'}) || 'GET');
   request->headers($params{'headers'} || {});
   request->unparsed_uri($params{'unparsed_uri'} || '/');
   request->uri($params{'uri'} || '/');
   request->path_info($params{'path_info'} || '');
   request->location($params{'location'} || '');
   request->uploads($params{'uploads'} || {});
   request->user($params{'user'});
   
   WebTek::Response->init;
   config->{'session'}->{'class'}->init;
}

sub dispatch {
   my ($self, $root) = @_;
   
   WebTek::Dispatcher->dispatch($root);
}

sub error {
   my ($self, $error) = @_;

   $self->log(WebTek::Logger::LOG_LEVEL_ERROR(), $error);
}

sub finalize { }

sub log {
   my ($class, $level, $msg) = @_;
   
   $level = (qw( debug info warning error fatal ))[$level];
   warn "[$level] $msg\n";
}

1;