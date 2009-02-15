use WebTek::Export qw( add_macro );

sub add_macro :Macro
   :Info(numerical addition)
   :Param(value1="12.3")
   :Param(value2="385.1")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} + $params{'value2'};
}
