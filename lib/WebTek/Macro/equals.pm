use WebTek::Export qw( equals_macro );

sub equals_macro :Macro 
   :Info(equals to values and returns the strings 0 or 1)
   :Param(value1="abc")
   :Param(value2="abc")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} eq $params{'value2'} ? 1 : 0;
}
