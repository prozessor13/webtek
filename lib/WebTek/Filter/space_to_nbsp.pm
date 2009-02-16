sub space_to_nbsp :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/( +)/"&nbsp;" x length($1)/eg;
   return $string;   
}
