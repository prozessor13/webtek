package WebTek::Filter;

use strict;

sub encode_qq :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\"/\\\"/g;
   return $string;
}

1;