package WebTek::Session::DB;

# max demmelbauer
# 22-09-08
#
# store session in DB

use strict;
use WebTek::Globals;
use base qw( WebTek::Model WebTek::Session );
use Storable qw( freeze thaw );
use WebTek::Util::Base64 qw( encode_base64 decode_base64 );

our $LastCleanup = {};

sub CLEANUP_INTERVAL { 10 * 60 } # in seconds

sub DATATYPES { { 'data' => DATA_TYPE_BLOB } }

sub TABLE_NAME { 'session' }

#... register notificatins 
event->register('name' => 'request-end', 'method' => 'cleanup');

sub _macro { # HACK because of multiple inheritance
   my ($self, $name) = @_;

   return eval { $self->SUPER::_macro($name) } || $self->data->{$name};
}

# --------------------------------------------------------------------------
# override model methods to serialize the session data
# --------------------------------------------------------------------------

sub new_from_db {
   my $class = shift;
   my $content = shift;    # hashref with content

   #... load and deserialize from db
   my $self = $class->SUPER::new_from_db($content);
   $self->data($self->data ? thaw(decode_base64($self->data)) : {});
   #... store user, content, language in session
   $self->user($self->data->{'user'});
   $self->language($self->data->{'language'});
   $self->country($self->data->{'country'});
   
   return $self;
}

sub save {
   my $self = shift;
   
   #... save user, country, language in data
   $self->data->{'user'} = $self->user;
   $self->data->{'language'} = $self->language;
   $self->data->{'country'} = $self->country;
   #... serialize data and save in db
   $self->data(encode_base64(freeze($self->data))); # serialize
   $self->SUPER::save;
   $self->data(thaw(decode_base64($self->data))); # unserialize
} 

# --------------------------------------------------------------------------
# cleanup the session table every CLEANUP_INTERVAL seconds
# --------------------------------------------------------------------------

sub cleanup {
   my $class = shift;
   
   return if $LastCleanup->{app->name} + CLEANUP_INTERVAL > time;
   log_debug "WebTek::Session: do a cleanup in DB";
   my $expiry_time = config->{'session'}->{'expiry-time'};
   my $invalid_time = date(time - $expiry_time)->to_db($class->db);
   my $sessions = $class->where("create_time < '$invalid_time'");
   foreach my $session (@$sessions) { $session->delete }
   $LastCleanup->{app->name} = time;
}

1;