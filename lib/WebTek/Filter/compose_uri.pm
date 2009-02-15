use WebTek::Export qw( compose_uri );

sub compose_uri {
   my ($handler, $uri, $params) = @_;
   
   #... encode params
   my $encoded = {};
   sub _encode {
      my $string = shift;
      $string =~ s/([^\w-\.\!\~\*\'\(\)])/'%'.sprintf("%02x", ord($1))/eg;
      return $string;
   }
   foreach my $key (keys %$params) {
      $encoded->{_encode($key)} =~ _encode($params->{$key});
   }
   
   #... compose uri
   return keys %$params
      ? "$uri?" . join("&", map("$_=$params->{$_}", keys %$params))
      : $uri;
}
