package WebTek::Filter;

use strict;

sub uppercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return uc($string);
}

1;