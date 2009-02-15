use WebTek::Export qw( encode_q );

sub encode_q :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\'/\\\'/g;
   return $string;
}
