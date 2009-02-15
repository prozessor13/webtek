use Date::Language;
use Date::Format qw( time2str );
use WebTek::Data::Date qw( date );
use WebTek::Export qw( format_date );

sub DateLanguageForCode { {
   'de' => 'German',
   'en' => 'English',
} }

sub format_date :Filter {
   my ($handler, $date, $params) = @_;

   $date = date($date) unless ref $date;
   return "[invalid date format]" unless $date->is_valid;
   my $format = $params && $params->{'format'} || "%d.%m.%Y %H:%M";
   my $timezone = $params && $params->{'timezone'} || $date->timezone;
   my $l = DateLanguageForCode->{
      $params->{'language'}
      || eval { $handler->session->langauge }
      || eval { $handler->request->language }
   };
   return $l
      ? Date::Language->new($l)->time2str($format, $date->to_time, $timezone)
      : time2str($format, $date->to_time, $timezone);
}
