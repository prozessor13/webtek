package WebTek::Response;

# max demmelbauer
#
# remember all things needed for response

use strict;
use Encode;
use WebTek::Util qw( assert make_accessor );
use WebTek::Event qw( event );
use WebTek::Logger qw( ALL );
use WebTek::Config qw( config );
use WebTek::Request qw( request );
use WebTek::Exception;
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );
use WebTek::Data::Date qw( date );
use WebTek::Data::Struct qw( struct );
use WebTek::Export qw( response );
use base qw( WebTek::Handler );

make_accessor('messages', 'Hander');
make_accessor('status', 'Macro');
make_accessor('content_type', 'Macro');
make_accessor('charset', 'Macro');
make_accessor('body', 'Macro');
make_accessor('action', 'Macro');
make_accessor('title', 'Macro');
make_accessor('format', 'Macro');
make_accessor('buffer');
make_accessor('headers');
make_accessor('cookies');
make_accessor('no_cache');
make_accessor('pretty');

our $Response;

sub response :Handler { $Response or throw "Response not initialized!" }

sub init {
   my $self = shift->new;

   $self->status(200);
   $self->headers({
      'Cache-Control' => 'no-cache',
      'Expires' => date('now')->to_rfc_822,
   });
   $self->cookies({});
   $self->charset(config->{'charset'});
   $self->content_type('text/html');
   $self->format(request->format);
   $self->messages(WebTek::Response::Message->new);

   $Response = $self;
}

sub write {
   my ($self, $string) = @_;

   $self->buffer($self->buffer . $string);
}

sub cookie {
   my ($self, %args) = @_;  # args are "value", "name", "path"
   
   assert $args{'name'}, "no name defined!";
   $args{'path'} ||= request->location || '/';
   
   $self->cookies->{$args{'name'}} = \%args;
   log_debug "set cookie: $args{'name'}";
}

sub header {
   my ($self, $name, $value) = @_;
   
   $self->headers->{$name} = $value;
}

sub redirect {
   my $self = shift;
   my $url = shift;              # string with redirect-url
   my $status = shift || 302;    # status code
   
   #... set redirect headers
   if (request->is_ajax) {
      $self->header('X-Ajax-Redirect-Location' => $url);
      $self->write(' ');   # for safari :(
   } else {
      $self->header('Location' => $url);
      $self->status($status);
   }
   #... remember things in session
   my $session = WebTek::Session::session();
   $session->messages($self->messages);
   $session->no_cache($self->no_cache);
   
   WebTek::Exception::Redirect->throw;
}

sub json {
   my ($self, $data) = @_;
   
   # this code is from Encode::JavaScript::UCS
   my $js = $self->encode_js($data);
   my $json = Encode::encode("ascii", $js, sub { sprintf("\\u%04x", $_[0]) });
   $self->header('X-JSON' => $json);
}

sub message_macro :Macro {
   my ($self, %params) = @_;
   
   my $name = $params{'name'} || 'default';
   my $msg = $self->messages->$name();
   $self->messages->$name($params{'flush'}) if exists $params{'flush'};
   return $msg;
}

sub message :Handler {
   my $self = shift;
   
   $self->messages->default(shift) if @_;
   return $self->messages;
}

package WebTek::Response::Message;

use strict;
use overload '""' => sub { shift->{'default'} };

our $AUTOLOAD;

sub new { bless {}, shift }

sub _macro { $_[0]->{$_[1]} }

sub AUTOLOAD {
   my $self = shift;
   my $name = $AUTOLOAD =~ /::([^:]+)$/ ? $1 : $AUTOLOAD;
   return if $name eq 'DESTROY';
   
   if (@_) {
      $self->{$name} = shift;
      $Response->no_cache(1);
   }
   return $self->{$name};
}

1;