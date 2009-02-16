sub count :Filter
   :Param(take a list, and convert it to a number - the list's size)
   :Param(to enable <% customer.profiles | count %>)
{
   my ($handler, $input, $params) = @_;
   return scalar(@$input);
}
