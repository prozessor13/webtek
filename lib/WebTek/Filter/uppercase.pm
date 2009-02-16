sub uppercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return uc($string);
}
