package WebTek::Request;

# max demmelbauer
# 14-02-06
#
# store all important informations of the request

use strict;
use WebTek::Util qw( assert make_accessor );
use WebTek::Logger qw( ALL );
use WebTek::Config qw( config );
use WebTek::Exception;
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );
use WebTek::Export qw( request );
use base qw( WebTek::Handler );

make_accessor('path', 'Handler');	# WebTek::Request::Path object
make_accessor('param', 'Handler');
make_accessor('uri', 'Macro');
make_accessor('unparsed_uri', 'Macro');
make_accessor('path_info', 'Macro');
make_accessor('location', 'Macro');	# Apache <location> e.g. "/webtek-app"
make_accessor('hostname', 'Macro');	# e.g. "www.myserver.com"
make_accessor('remote_ip', 'Macro');
make_accessor('page', 'Macro');
make_accessor('action', 'Macro');
make_accessor('method', 'Macro');	# e.g. "POST"
make_accessor('language', 'Macro');
make_accessor('is_ajax', 'Macro');
make_accessor('user_agent', 'Macro');
make_accessor('referer', 'Macro');
make_accessor('country', 'Macro');
make_accessor('accept', 'Macro');
make_accessor('format', 'Macro');
make_accessor('user', 'Macro');
make_accessor('cookies');
make_accessor('uploads');
make_accessor('no_cache');
make_accessor('data');

our $Request;

sub request :Handler { $Request or throw "Request not initialized" }

sub init {
   $Request = shift->new;
   $Request->data({});
}

sub header { $_[0]->headers->{$_[1]} }

sub cookie { $_[0]->cookies->{$_[1]} }

sub upload { $_[0]->uploads->{$_[1]} }

sub is_get { $_[0]->method eq 'GET' }

sub is_post { $_[0]->method eq 'POST' }

sub is_put { $_[0]->method eq 'PUT' }

sub is_delete { $_[0]->method eq 'DELETE' }

sub headers :Handler {
   my $self = shift;
   
   #... parse and set headers
   if (@_) {
      my $headers = shift;
      my $accept = $headers->{'Accept'};
      $self->accept($accept);
      $self->format(config->{'format-for-content-type'}->{$accept} || 'html');
      $self->user_agent($headers->{'User-Agent'});
      $self->referer($headers->{'Referer'});
      $self->is_ajax($headers->{'X-Requested-With'} eq 'XMLHttpRequest');
      $self->language(lc substr $headers->{'Accept-Language'}, 0, 2);
      $self->country(lc substr $headers->{'Accept-Language'}, 3, 2);
      $self->{'headers'} = $headers;
   }
   
   #... set defaults
   $self->language(config->{'default-language'}) unless $self->language;
   
   return $self->{'headers'};
}

sub params :Handler {
   my $self = shift;
   
   #... group and set params
   if (@_) {
      #... set params
      my $params = shift;
      WebTek::Request::Param->_new($params);
      $self->param(WebTek::Request::Param->_new($params));
      #... group params
      my $grouped = $self->{'params'} = WebTek::Request::Param->_new({});
      foreach (sort { @$b <=> @$a } map {[reverse split "___"]} keys %$params) {
         my ($group, $key, @groups) = ($grouped, @$_);
         @groups = reverse @groups;
         my $name = join "___", (@groups, $key);
         foreach my $g (@groups) {
            $group = $group->_handler($g)
               || $group->_handler($g, WebTek::Request::Param->_new({}));
         }
         if ($group->_handler($name)) {
            log_warning "omit param $name, because a group alreay exists!";            
         } else {
            $group->_param($key, $params->{$name});
         }
      }
   }
   
   return $self->{'params'};
}

package WebTek::Request::Path;

use strict;

our $AUTOLOAD;

sub new { bless $_[1] || [], $_[0] }

sub page { $_[0]->[-1] }

sub _handler {
   my ($self, $name) = @_;
   
   return $self->$name();
}

sub AUTOLOAD {
   my $path = shift;
   my $page_name = $AUTOLOAD =~ /::([^:]+)$/ ? $1 : $AUTOLOAD;
   return if $page_name eq 'DESTROY';
   
   for (my $i=scalar(@$path)-1; $i>=0; $i--) {
      return $path->[$i] if lc($path->[$i]->page_name) eq lc($page_name);
   }
   return undef;
}

package WebTek::Request::Param;

use strict;

our $AUTOLOAD;

sub _new {
   my ($class, $params) = @_;
   
   return bless {
      (map { $_ => $params->{$_}->[0] } keys %$params),
      '_params' => $params,
      '_handlers' => {},
   }, $class;
}

sub _handler {
   my ($self, $name, @handler) = @_;
   
   $self->{'_handlers'}->{$name} = $handler[0] if @handler;
   return $self->{'_handlers'}->{$name};
}

sub _macro { $_[0]->{$_[1]} }

sub _param {
   my ($self, $name, @param) = @_;

   #... set param
   if (@param) {
      $self->{'_params'}->{$name} = $param[0];
      $self->{$name} = $self->{'_params'}->{$name}->[0];
   }
   #... get param
   return $self->{'_params'}->{$name};
}

sub to_hash {
   my $self = shift;
   
   my $hash = { %$self };
   delete $hash->{'_params'};
   delete $hash->{'_handlers'};
   return $hash;
}

sub AUTOLOAD {
   my ($self, $return_type) = @_;
   my $name = $AUTOLOAD =~ /::([^:]+)$/ ? $1 : $AUTOLOAD;
   return if $name eq 'DESTROY';
   
   my ($handler, $param) = ($self->_handler($name), $self->_param($name));
   
   return undef unless $handler or $param;
   return $handler if $handler;
   return ref $return_type eq 'ARRAY'
      ? $param
      : wantarray ? @$param : $param->[0];
}

package WebTek::Request::Upload;

use WebTek::Util qw( make_accessor );

make_accessor('name');
make_accessor('filename');
make_accessor('content_type');
make_accessor('size');
make_accessor('tempname');

sub new { bless { @_[1 .. $#_] }, $_[0] }

sub link_to { WebTek::Util::copy(shift->tempname, shift) }

1;
