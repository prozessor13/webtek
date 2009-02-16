sub boolean :Filter {
   my ($handler, $value, $params) = @_;
   
   my $yes = defined $params->{'yes'} ? $params->{'yes'} : 'yes';
   my $no = defined $params->{'no'} ? $params->{'no'} : 'no';
   return $value ? $yes : $no; 
}
