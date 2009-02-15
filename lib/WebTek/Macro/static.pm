use WebTek::Export qw( static );

sub static :Macro
   :Param(render the src to a static file)
   :Param(filename="filename.ext" relative filename (from the static dir))
{
   my ($self, %params) = @_;
   
   my $fname = $params{'filename'} ? "/$params{'filename'}" : "";
   return config->{'static'}->{'href'} . $fname ;
}
