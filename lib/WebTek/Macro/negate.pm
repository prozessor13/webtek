sub negate_macro :Macro :Public
   :Param(value="12.3")
{
   my ($self, %params) = @_;
   
   return - $params{'value'};
}