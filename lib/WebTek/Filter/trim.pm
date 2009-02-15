use WebTek::Export qw( trim );

sub trim :Filter {
   my ($handler, $string, $param) = @_;
   
   $string =~ s/\A\s+//;
   $string =~ s/\s+\z//;
   return $string;
}

