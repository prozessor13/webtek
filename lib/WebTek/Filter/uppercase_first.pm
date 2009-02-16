sub uppercase_first :Filter {
   my ($handler, $string, $params) = @_;
   
   return ucfirst($string);
}
