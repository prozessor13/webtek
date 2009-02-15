use WebTek::Export qw( format_time );

sub format_time :Filter {
   my ($handler, $time, $params) = @_;

   my $format = $params && $params->{'format'} || "%H:%M:%S";
   my $date = WebTek::Data::Date::date("2000-01-01 00:00:00 GMT")->to_time;
   return time2str($format, $time + $date, "GMT");
}
