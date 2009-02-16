sub encode_q :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\'/\\\'/g;
   return $string;
}
