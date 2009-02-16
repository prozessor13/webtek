sub parse_number :Filter {
   my ($handler, $number, $params) = @_;
   
   #... localize
   my $c = WebTek::Config::config('numbers');
   my $language = $params->{'language'} || eval { $handler->request->language };
   my $country = uc($params->{'country'} || eval { $handler->request->country });
   my $locale = $country ? "$language\_$country" : $language;
   if (my $config = $c->{"$language\_$country"} || $c->{$language}) {
      my $thousands_sep = $config->{'thousands_sep'};
      $thousands_sep = '\.' if $thousands_sep eq '.';
      my $decimal_point = $config->{'decimal_point'};
      $decimal_point = '\.' if $decimal_point eq '.';
      $number =~ s/$thousands_sep//g;
      $number =~ s/$decimal_point/\./g;
   }
   
   return 0+$number;
}
