use Encode qw( encode );
use WebTek::Export qw( charset );

sub charset :Filter {
   my ($handler, $string, $params) = @_;

   my $charset = $params->{'charset'};
   return ($charset and $charset !~ /^utf-?8/i)
      ? encode($charset, $string)
      : $string;
}
