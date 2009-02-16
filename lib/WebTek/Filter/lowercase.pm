sub lowercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return lc($string);
}
