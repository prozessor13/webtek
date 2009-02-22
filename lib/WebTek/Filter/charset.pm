package WebTek::Filter;

use strict;
use Encode qw( encode );

sub charset :Filter {
   my ($handler, $string, $params) = @_;

   my $charset = $params->{'charset'};
   return ($charset and $charset !~ /^utf-?8/i)
      ? encode($charset, $string)
      : $string;
}

1;