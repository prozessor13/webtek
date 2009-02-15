use WebTek::Export qw( match_macro );

sub match_macro :Macro 
   :Param(combine two values with logical or)
   :Param(value="abc")
   :Param(regexp=".*")
{
   my ($self, %params) = @_;
   
   return $params{'value'} =~ /$params{'regexp'}/;
}
