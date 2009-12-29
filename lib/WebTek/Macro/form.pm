package WebTek::Page;

use strict;


sub form :Macro
   :Param(render a form tag)
   :Param(action="action" optional, default=response->action)
   :Param(method="post" optional, default=post)
   :Param(all other params are forwarded into the form tag)
{
   my ($self, %p) = @_;
   
   #... remember the form errors
   $self->{'__form_errors'} = [];
   #... process form action
   $p{action} = $p{action}
      ? $p{action} =~ /^\// ? $p{action} : $self->href(action => $p{action})
      : response->action || request->is_rest
         ? $self->href : $self->href(action => request->action);
   #... process form method
   my $method = input_tag({
      type => 'hidden', name => '_method', value => $p{method} || 'post',
   });
   $p{method} = $p{method} =~ /^get|post$/i ? $p{method}: 'post';
   
   return form_tag(\%p) . $method . '<div>';
}

1;