sub select :Macro
   :Param(renders a select box (=dropdown))
   :Param(values="value1,value2,value3" define the values)
   :Param(displays="display1,display2,display3" define the display (optional))
   :Param(selected="value2" set the selected option)
   :Param(separator="\|" define a regexp for the separator, default is ",")
{
   my ($self, %params) = @_;
   
   $params{'type'} = "select";
   my $sep = $params{'separator'} || ',';
   my @options = ();
   my @values = ref $params{'values'}
      ? @{$params{'values'}}
      : split($sep, $params{'values'});
   my @displays = ref $params{'displays'}
         ? @{$params{'displays'}}
         : split($sep, $params{'displays'});
   delete $params{'values'};
   delete $params{'displays'};
   for (my $i=0; $i<scalar(@values); $i++) {
      push @options, {
         'value' => $values[$i],
         'display' => exists $displays[$i] ? $displays[$i] : $values[$i]
      };
   }
   $params{'options'} = \@options;
   return $self->form_field(%params);
}
