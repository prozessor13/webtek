package WebTek::Filter;

use strict;

sub lowercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return lc($string);
}

1;