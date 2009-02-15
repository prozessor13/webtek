use WebTek::Export qw( newline_to_br );

sub newline_to_br :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\n/\<br\>/g;
   return $string;
}
