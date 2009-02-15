use WebTek::Export qw( form );

sub form :Macro
   :Param(render a form tag)
   :Param(action="action" optional, default action = response->action)
   :Param(method="post" optional, default = post)
   :Param(all other params are forwarded into the form tag)
{
   my ($self, %params) = @_;
   
   #... remember the form errors
   $self->{'__form_errors'} = $self->_suppress_errors ? undef : [];
   
   if ($params{'action'}) {
      $params{'action'} = $params{'action'} =~ /^\//
         ? $params{'action'}                             # absolute href
         : $self->href('action' => $params{'action'});   # relative href
   } else {
      $params{'action'} ||= response->action
         || $self->href('action' => request->action);
   }
   
   $params{'method'} ||= "post";
      
   return form_tag(\%params) . "<div>";
}
