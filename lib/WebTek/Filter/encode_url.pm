package WebTek::Filter;

use strict;

sub encode_url :Filter {
   my ($handler, $string, $params) = @_;
   use bytes;

   $string =~ s/\ /\+/g;   # convert spaces to +
   $string =~ s/([^a-zA-Z0-9\+\_\-\/\:\.])/'%'.sprintf("%02x", ord($1))/eg;
   return $string;
}

1;