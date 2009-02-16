sub and_macro :Macro 
   :Info(combine two values with logical and)
   :Param(value1="abc")
   :Param(value2="abc")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} && $params{'value2'};
}
