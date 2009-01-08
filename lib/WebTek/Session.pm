package WebTek::Session;

# max demmelbauer
# 17-03-06
#
# session object for webtek

use strict;
use WebTek::Util qw( assert make_accessor );
use WebTek::Exception;
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );
use WebTek::Export qw( session );
use base qw( WebTek::Handler );
use Date::Parse qw( str2time );

our $AUTOLOAD;
our $Session;

#... get the session for the actual request
sub session :Handler { $Session or throw "Session not initialized" }

#... define handlers/macros
make_accessor('user', 'Handler', 'Macro');
make_accessor('country', 'Macro');
make_accessor('language', 'Macro');

#... load globals here to load attributes correctly
use WebTek::Globals;

sub _init { die "WebTek::Session::_init not implemented!" }

sub find_one { die "WebTek::Session::find_one not implemented!" }

#... fetch cookie from db or create a new session
sub init {
   my $class = shift;

   #... check for an already existing session
   if (my $id = request->cookie(config->{'session'}->{'cookie-name'})) {
      my $session = $class->find_one(
         'id' => $id,
         'ip_address' => request->remote_ip,
      );
      if ($session && !$session->is_expired) {
         $session->expand;
         # may set messages (from previous request) to response
         if (defined $session->messages) {
            WebTek::Response::response()->messages($session->messages);
            $session->messages(undef);
         }
         # may set no_cache info (from previous request) to request
         WebTek::Request::request()->no_cache($session->no_cache);
         $session->no_cache(undef);
         return $Session = $session;
      } elsif ($session) {
         $session->delete;
      }
   }
   
   #... create a new session
   return $Session = $class->create_new_for_ip(request->remote_ip);
}

sub create_new_for_ip {
   my ($class, $ip_address) = @_;
      
   #... create unique session key
   my $id;
   while (1) {
      $id = "";
      foreach (0 .. 31) {
         my $x = sprintf "%1x", int(rand(16));
         $id .= "$x";
      }
      #... check if id is not already used
      last unless $class->find_one('id' => $id);
   }
   
   #... set session cookie
   WebTek::Response::response()->cookie(
      'name' => config->{'session'}->{'cookie-name'},
      'value' => $id,
      'path' => config->{'session'}->{'cookie-path'},
   );
   
   #... create and return session obj
   return $class->new(
      'id' => $id,
      'data' => {},
      'ip_address' => $ip_address,
      'create_time' => date('now'),
   );
}

sub is_expired { (
   time > $_[0]->create_time + config->{'session'}->{'expiry-time'}
) }

sub expand { $_[0]->create_time(date('now')) }

# --------------------------------------------------------------------------
# AUTOLOAD for direct access to $self->{'data'} in code and macro
# --------------------------------------------------------------------------

sub _macro {
   my ($self, $name) = @_;

   return $self->SUPER::_macro($name) || $self->data->{$name}
}

sub AUTOLOAD {
   my $self = shift;
   my $method = $AUTOLOAD =~ /::([^:]+)$/ ? $1 : $AUTOLOAD;
   return if $method eq 'DESTROY';
 
   assert ref($self), "Session::AUTOLOAD called in class context: $method";
 
   if (@_) { $self->data->{$method} = shift }
   return $self->data->{$method};
}

1;