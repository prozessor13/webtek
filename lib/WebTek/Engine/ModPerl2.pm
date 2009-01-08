package WebTek::Engine::ModPerl2;

# max demmelbauer
# 30-12-07
#
# initialize the WebTek::Request with data from mod_perl2

use strict;
use WebTek::App qw( app );
use WebTek::Util qw( assert r );
use WebTek::Config qw( config );
use WebTek::Logger qw( ALL );
use WebTek::Request qw( request );
use WebTek::Response qw( response );
use WebTek::Exception;
use Apache2::Cookie;
use Apache2::Request;
use Apache2::Upload;
use Encode qw( _utf8_on decode );

my @LogLevels = qw( debug info warn error crit );

sub prepare {
   my $self = shift;

   WebTek::Request->init;

   my $is_utf8 = (config->{'charset'} =~ /utf-?8/i);
      
   #... create Apache2::Request
   my %config = %{config('mod_perl2')->{'request'}};
   assert $config{'POST_MAX'}, "config request.POST_MAX not defined!";
   assert $config{'TEMP_DIR'}, "config request.TEMP_DIR not defined!";
   my $req = Apache2::Request->new(r, %config);

   request->hostname(r->hostname);
   request->remote_ip(r->connection->remote_ip);
   request->method(uc(r->method));
   request->headers(r->headers_in);
   request->user(r->user);

   #... get location, uri and path_info
   my ($uri, $path_info, $location) = (r->uri, r->uri, r->location);
   if ($is_utf8) {
       _utf8_on($uri);
       _utf8_on($path_info);
       _utf8_on($location);
   }
   $path_info =~ s|$location||;
   request->unparsed_uri(r->unparsed_uri);
   request->uri($uri);
   request->path_info($path_info);
   request->location($location);

   #... read cookies
   my %cookies = Apache2::Cookie->fetch(r);
   request->cookies({map {$_ => $cookies{$_}->value || undef} keys %cookies });
   
   #... read query parameters
   my $table = $req->param;
   my $params = {};
   if ($table) {
      $table->do(sub {
         my ($key, $value) = @_;
         $params->{$key} ||= [];
         if ($is_utf8) { _utf8_on($value) }
         else { $value = decode(config->{'charset'}, $value) }
         push @{$params->{$key}}, $value;
         1;
      });      
   }
   request->params($params);

   #... read uploads
   request->uploads({ map { $_->name => WebTek::Request::Upload->new(
      'name' => $_->name,
      'filename' => $_->filename,
      'size' => $_->size,
      'content_type' => $_->info->{'Content-Type'},
      'tempname' => $_->tempname,
   ) } map { $req->upload($_) } $req->upload });

   WebTek::Response->init;
   config->{'session'}->{'class'}->init;
}

sub dispatch {
   my ($self, $root) = @_;
   
   WebTek::Dispatcher->dispatch($root);
}

sub error {
   my ($self, $error) = @_;
   
   log_error $error;
   r->content_type('text/html');
   r->status(500);
   r->print("<html><body><b>general error</b>");
   if (config()->{'display-general-errors-to-browser'}) {
      $error =~ s/\n/<br>/g;
      r->print("<br><br>$error");
   }
   r->print("</body></html>");
}

sub finalize {
   my $self = shift;
   
   #... print status
   r->status(response->status);
   
   #... print headers
   my %headers = %{response->headers};
   r->content_type(response->content_type);
   map { r->err_headers_out->set($_ => $headers{$_}) } keys %headers;

   #... print cookies
   my $cookies = response->cookies;
   foreach my $name (keys %$cookies) {
      my $cookie = $cookies->{$name};
      #... prepare arg-keys to work with Apache2::Cookie constructor
      map { $cookie->{"-$_"} = delete $cookie->{$_} } keys %$cookie;
      #... bake cookie
      my $c = Apache2::Cookie->new(r, %$cookie);  
      $c->bake(r);
   }
   
   #... print body (may convert to a different encoding)
   (response->content_type =~ /^text/ and config->{'charset'} !~ /utf-?8/i)
      ? r->print(encode(config->{'charset'}, response->buffer))
      : r->print(response->buffer);
}

sub log {
   my ($class, $level, $msg) = @_;
   
   $level = $LogLevels[$level];
   r->log->$level($msg);
}

1;
