sub link :Macro
   :Param(href="xyz" link destination)
   :Param(display="xyz" link display name)
   :Param(all other params are forwarded into the a tag)
{
   my ($self, %params) = @_;
 
   $params{'display'} ||= $params{'href'};
   return a_tag(\%params);
}
