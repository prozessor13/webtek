sub or_macro :Macro 
   :Param(combine two values with logical or)
   :Param(value1="abc")
   :Param(value2="abc")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} || $params{'value2'};
}
