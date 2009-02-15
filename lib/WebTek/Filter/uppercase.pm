use WebTek::Export qw( uppercase );

sub uppercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return uc($string);
}
