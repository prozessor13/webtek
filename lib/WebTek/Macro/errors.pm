package WebTek::Page;

sub errors :Macro
   :Info(prints the errors of the page)
   :Param(separator="&lt;br /&gt;" define the separator between each error-msg (optional))
{
   my ($self, %params) = @_;

   my @keys = $params{'keys'}
      ? split ",", $params{'keys'}
      : keys %{$self->_errors};

   #... create the error msg
   my $sep = exists $params{'separator'} ? $params{'separator'} : "<br />";
   return join $sep, map {
      $self->message('key' => $self->error_on($_), %params)
   } @keys;
}

1;