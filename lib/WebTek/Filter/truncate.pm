use WebTek::Export qw( truncate );

sub truncate :Filter {
   my ($handler, $string, $params) = @_;

   assert $params->{'limit'}, "'limit' parameter mandatory";
   
   if (length($string) > $params->{'limit'}) {
      my $suffix = defined $params->{'suffix'} ? $params->{'suffix'} : '...';
      my $offset = $params->{'limit'} - length($suffix);
      substr($string, $offset) = $suffix;
   }
   return $string;
}
