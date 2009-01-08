package WebTek::Event;

# NOTE: this code is originally from adrian smith <adrian.m.smith@gmail.com>

use strict;
use WebTek::Util qw( assert );
use WebTek::Logger qw( ALL );
use WebTek::Exception;
use WebTek::Export qw( event );

our $SharedInstance;

sub new { bless { }, shift }

sub event { $SharedInstance ||= __PACKAGE__->new }

sub register {
   my ($self, %param) = @_;
   
   assert $param{'name'}, "name not defined!";
   assert $param{'method'}, "method not defined!";
   
   # set default values
   my $names = ref $param{'name'} ? $param{'name'} : [$param{'name'}];
   my $method = $param{'method'};
   my $obj = $param{'obj'} || caller;
   my $priority = $param{'priority'} || 5;
   
   foreach my $name (@$names) {
      $self->{$name}->{'all'}->{"$obj->$method"} = [$obj, $method, $priority];
      $self->_create_list($name);
      log_debug "$$: registered event '$name' for $obj\->$method";      
   }
}

sub notify {
   my ($self, $name, @args) = @_;

   foreach my $e (@{$self->{$name}->{'list'}}) {
      my $obj = $e->[0];
      my $method = $e->[1];
      unless (eval { $obj->$method(@args); 1 }) {
         log_fatal "error executing event '$name' on object $obj: $@";
      }
      log_debug "$$: called $obj\->$method for event '$name'";
   }
}

sub remove_all_on_object {
   my $self = shift;
   my $obj = shift;         # object, target of events

   my $is_ref = ref $obj;
   while (my ($name, $info) = each %$self) {
      foreach my $id (keys %{$info->{'all'}}) {
         if ($is_ref) {
            delete $info->{'all'}->{$id} if $info->{'all'}->{$id}->[0] == $obj;
         } else {            
            delete $info->{'all'}->{$id} if $info->{'all'}->{$id}->[0] eq $obj;
         }
      }
      $self->_create_list($name);
   }
   log_debug "$$: removed all events on $obj";
}

sub _create_list {
   my ($self, $name) = @_;
   
   my @list = sort { $a->[2] <=> $b->[2] } values %{$self->{$name}->{'all'}};
   $self->{$name}->{'list'} = \@list;   
}

1;
