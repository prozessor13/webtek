use WebTek::Export qw( textarea );

sub textarea :Macro
   :Param(render an textarea, all Parameter from the input macro works here)
{
   my ($self, %params) = @_;
   
   $params{'type'} = "textarea";
   return $self->form_field(%params);
}
