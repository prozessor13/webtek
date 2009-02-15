use WebTek::Export qw( uppercase_first );

sub uppercase_first :Filter {
   my ($handler, $string, $params) = @_;
   
   return ucfirst($string);
}
