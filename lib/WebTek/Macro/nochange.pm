sub nochange_macro :Macro :Public
   :Param(takes param and returns it, without change)
   :Param(useful for applying filters)
   :Param(value="abc")
{
   my ($self, %params) = @_;
   return $params{'value'};
}
