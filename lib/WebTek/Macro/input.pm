use WebTek::Export qw( input );

sub input :Macro
   :Param(renders an form input tag)
   :Param(name="x" input-tag name)
   :Param(type="text" optional, default = text)
   :Param(value="value" optional, default = request->param->name or on submit-buttons the name)
   :Param(default_value="value" optional, set this value if no other value (request, handler, value) is defined)
   :Param(handler="handler" optional, with this Parameter the default value is also searched in the handler)
   :Param(all other params are forwarded into the form tag)
{
   my ($self, %params) = @_;

   $params{'type'} ||= 'text';
   return $self->form_field(%params);
}
