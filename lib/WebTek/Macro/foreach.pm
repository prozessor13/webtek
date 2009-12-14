package WebTek::Handler;

sub foreach_macro :Macro
   :Info(render a template for each item in a list)
   :Param(list="<% some_list %>")
   :Param(iterator="iteratorname")
   :Param(do~"some template code")
   :Param(template="list_item", alternativ to the do parameter you can define a template which shoud be rendered for each item)
{
   my ($self, %params) = @_;
   
   assert($params{'list'}, "no list defined");
   assert(ref $params{'list'} eq 'ARRAY', "list not type of ARRAY");
   assert(
      !$self->can_handler($params{'iterator'}),
      "there exists already a handler for this iterator-name '" .
         $params{'iterator'} . "', please choose another iterator-name"
   ) if $params{'iterator'};
   assert(
      ($params{'do'} or $params{'template'}),
      "no template or do-block defined!"
   );
   assert(
      !($params{'do'} and $params{'template'}),
      "both, template and do-block defined, please set only one of them!"
   );
   assert(
      (!$params{'template'} or $self->can('render_template')),
      "handler can only render strings, not templates"
   );

   my $output;
   my $p = {};
   foreach my $item (@{$params{'list'}}) {
      if (not ref $item) {
         assert($params{'iterator'}, "no iterator defined");
         $p = { $params{'iterator'} => $item };
      } elsif (ref $item eq 'HASH') {
         $p = $item;
      } elsif (ref $item eq 'ARRAY') {
         $p = { map { $_ => $item->[$_] } (0 .. scalar(@$item)-1) };
      } else {
         assert($params{'iterator'}, "no iterator defined");
         $self->handler($params{'iterator'}, $item);         
      }
      if ($params{'do'}) {
         $output .= $self->render_string($params{'do'}, $p);
      } else {
         $output .= $self->render_template($params{'template'}, $p);
      }
   }
   $self->handler($params{'iterator'}, undef);
   return $output;
}

1;