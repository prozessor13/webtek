use WebTek::Export qw( encode_qq );

sub encode_qq :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\"/\\\"/g;
   return $string;
}
