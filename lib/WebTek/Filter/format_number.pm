package WebTek::Filter;

use strict;

sub format_number :Filter {
   my ($handler, $number, $params) = @_;

   return $number unless $params;

   #... make kilo, mega, or whatever
   if (my $type = $params->{type}) {
      if ($type eq 'kilo') { $number /= 1_000; }
      elsif ($type eq 'mega') { $number /= 1_000_000; }
      elsif ($type eq 'giga') { $number /= 1_000_000_000; }
      elsif ($type eq 'kilobytes') { $number /= 1_024; }
      elsif ($type eq 'megabytes') { $number /= 1_048_576; }
      elsif ($type eq 'gigabytes') { $number /= 1_073_741_824; }
   }
   
   #... format number (make an sprintf)
   $number = sprintf($params->{format}, $number) if $params->{format};
   
   #... make thousand separators
   if ($params->{thousands_sep}) {
      $number = reverse $number;
      $number =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1\,/g;
      $number = scalar reverse $number; 
   }

   #... localize
   my $c = WebTek::Config::config('numbers');
   my $language = $params->{language} || eval { $handler->request->language };
   my $country = uc($params->{country} || eval { $handler->request->country });
   my $locale = $country ? "$language\_$country" : $language;
   if (my $config = $c->{"$language\_$country"} || $c->{$language}) {
      $number =~ s/\,/__T__/g;
      $number =~ s/\./__D__/g;
      $number =~ s/__T__/$config->{thousands_sep}/g;
      $number =~ s/__D__/$config->{decimal_point}/g;
   }
   
   return $number;
}

1;