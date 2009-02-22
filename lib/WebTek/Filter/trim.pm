package WebTek::Filter;

use strict;

sub trim :Filter {
   my ($handler, $string, $param) = @_;
   
   $string =~ s/\A\s+//;
   $string =~ s/\s+\z//;
   return $string;
}

1;