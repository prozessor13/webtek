package WebTek::Filter;

use strict;

sub encode_html :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/&/&amp;/g;
   $string =~ s/"/&quot;/g;
   $string =~ s/'/&apos;/g;
   $string =~ s/</&lt;/g;
   $string =~ s/>/&gt;/g;
   
   return $string;
}

1;