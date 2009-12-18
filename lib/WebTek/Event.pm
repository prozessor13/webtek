package WebTek::Event;

# NOTE: this code is originally from adrian smith <adrian.m.smith@gmail.com>

use strict;
use WebTek::Util qw( assert );
use WebTek::Export qw( event );
use WebTek::Logger qw( log_debug log_fatal );

our %Event;

sub _init { $Event{$::appname} ||= bless {}, shift }

sub event { $Event{$::appname} }

sub observe {
   my ($self, %params) = @_;
   my ($name, $method) = ($params{names} || $params{name}, $params{method});
   assert $name, 'name not defined';
   assert $method, 'method not defined';
   
   #... set default values
   my $names = ref $name ? $name : [ $name ];
   my $obj = $params{obj} || caller;
   my $method = $params{method};
   my $priority = $params{priority} || 5;
   
   foreach my $name (@$names) {
      $self->{$name}{all}{"$obj->$method"} = [$obj, $method, $priority];
      _create_list($self->{$name});
      log_debug "$$: observe event '$name' for $obj->$method";
   }
}

sub trigger {
   my ($self, %params) = @_;

   my ($name, $args, @return) = ($params{name}, $params{args} || []);
   foreach my $e (@{$self->{$name}{list} || []}) {
      my ($obj, $method) = @$e;
      if (not $params{obj} or _eq($params{obj}, $obj)) {
         eval { push @return, $obj->$method(@$args); 1 }
            or log_fatal "error executing event '$name' on object $obj: $@";
         log_debug "$$: called $obj\->$method for event '$name'";
      }
   }
   return @return;
}

sub remove_all_on_object {
   my ($self, $obj) = @_;   
   
   while (my ($name, $info) = each %$self) {
      foreach my $id (keys %{$info->{all}}) {
         delete $info->{all}{$id} if _eq($obj, $info->{all}{$id}[0]);
      }
      _create_list($self->{$name});
   }

   log_debug "$$: removed all events on $obj";
}

sub _eq { $_[0] == $_[1] || $_[0] eq $_[1] }

sub _create_list {
   $_[0]->{list} = [sort { $a->[2] <=> $b->[2] } values %{$_[0]->{all}} ];
}

1;