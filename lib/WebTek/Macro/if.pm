package WebTek::Handler;

sub if_macro :Macro
   :Param(render param yes or no, as of the result of the condition)
   :Param(condition="some value")
   :Param(true="some text" render this text if the condition is true)
   :Param(false="some text" render this text if the condition is false)
{
   my ($self, %params) = @_;
   
   assert exists $params{'condition'}, "no condition defined!";
   assert
      exists $params{'true'} || exists $params{'false'},
      "no true or false param defined!";
   return $params{'condition'} ? $params{'true'} : $params{'false'};
}

1;
