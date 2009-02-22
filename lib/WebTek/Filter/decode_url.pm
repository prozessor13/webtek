package WebTek::Filter;

use strict;

sub decode_url :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\+/\ /g;
   $string =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
   return $string;
}

1;