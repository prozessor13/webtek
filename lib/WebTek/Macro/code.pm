package WebTek::Page;

sub code :Macro
   :Info(executes perlcode and prints the result in the template)
   :Param(eval="some perl code")
   :Param(debug="1" returns the error-message if an error occoured, else an empty string will be returned)
{
   my ($self, %params) = @_;

   assert $self->EVAL_CODE_IN_MACROS, "no code eval allowed in page $self";
   assert $params{'eval'}, "param 'eval' not defined in code macro";

   my $html = eval "\{$params{'eval'}\}";
   return $@ if $@ and $params{'debug'};
   return $html;
}

1;