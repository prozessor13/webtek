use WebTek::Export qw( select_from_list );

sub select_from_list :Macro 
   :Param(renders a select box (=dropdown) from a list)
   :Param(list="&lt;% xyz_list %>" is the list of objects to be displayed)
   :Param(iterator="xyz" is the name of the variable containing the current value)
   :Param(value~"&lt;% xyz.id %>" is the internal scalar value to be used for each object)
   :Param(display~"&lt;% xyz.name | encode_html %>" is the value the user sees for each object)
   :Param(selected="&lt;% my_xyz %>" is the current object selected)
{
   my ($self, %params) = @_;
   
   assert($params{'list'}, "no list defined");
   assert($params{'iterator'}, "no iterator defined");
   assert(ref $params{'list'} eq 'ARRAY', "list not type of ARRAY");
   assert(
      !$self->can_handler($params{'iterator'}),
      "there exists already a handler for this iterator-name '" .
         $params{'iterator'} . "', please choose another iterator-name"
   );

   my @options = ();
   foreach my $item (@{$params{'list'}}) {
      $self->handler($params{'iterator'}, $item);
      push @options, {
         'value' => $self->render_string($params{'value'}),
         'display' => $self->render_string($params{'display'}),
      };
   };
  
   my $selected_str = undef;
   if ($params{'selected'}) {
      $self->handler($params{'iterator'}, $params{'selected'});
      $selected_str = $self->render_string($params{'value'});
   }

   $self->handler($params{'iterator'}, undef);

   delete $params{'list'};
   delete $params{'iterator'};
   delete $params{'selected'};
   delete $params{'display'};
   
   $params{'type'} = "select";
   $params{'options'} = \@options;
   $params{'value'} = $selected_str;
   
   return $self->form_field(%params);
}

