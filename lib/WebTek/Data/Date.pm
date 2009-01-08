package WebTek::Data::Date;

# max demmelbauer 
# 27-03-06
#
# date obj

use strict;
use WebTek::Config qw( config );
use Date::Parse qw( str2time );
use Date::Format qw( time2str );
use WebTek::Export qw( date );
use overload
   '0+' => \&to_number,
   '""' => \&to_string,
   '<=>' => \&cmp_time,
   'cmp' => \&cmp_string,
   'fallback' => 1;

sub date {
   my $date = shift;       # date or time
   my $timezone = shift;   # optional timezone
   
   $timezone ||= eval { WebTek::Request::request()->timezone };
   $timezone ||= config->{'default-timezone'} || 'GMT';

   my $time = $date =~ /^\d+$/
      ? $date
      : eval { $date eq 'now' ? time : str2time($date, $timezone) };
   __PACKAGE__->new($time, $timezone);
}

sub new { bless { 'time' => $_[1], 'timezone' => $_[2] }, $_[0] }

sub to_time { $_[0]->{'time'} }

sub to_number { 0 + $_[0]->{'time'} }

sub to_string {
   my ($self, %params) = @_;

   return undef unless $self->is_valid;
   $params{'format'} ||= "%d.%m.%Y %H:%M";
   $params{'timezome'} ||= $self->timezone;
   return time2str($params{'format'}, $self->to_time, $params{'timezone'});
}

sub to_db {
   my ($self, $db) = @_; # $db isa WebTek::DB object

   return $self->to_string(
      'format' => $db->config->{'date-format'},
      'timezone' => $db->config->{'timezone'},
   );
}

sub to_rfc_822 { shift->to_string('format' => '%a, %d %b %Y %H:%M:%S %z') }

sub timezone { shift->{'timezone'} }

sub is_valid { defined shift->{'time'} }

sub cmp_time {
   my ($self, $other) = @_;
   
   if (ref $other) { $other = $other->to_time }
   return $self->to_time <=> $other;
}

sub cmp_string {
   my ($self, $other) = @_;
   
   if (ref $other) { $other = $other->to_string }
   return $self->to_string cmp $other;
}

1;