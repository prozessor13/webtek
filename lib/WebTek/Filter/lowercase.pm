use WebTek::Export qw( lowercase );

sub lowercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return lc($string);
}
