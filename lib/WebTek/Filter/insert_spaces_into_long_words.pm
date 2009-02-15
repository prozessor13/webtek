use WebTek::Export qw( insert_spaces_into_long_words );

sub insert_spaces_into_long_words :Filter :Public
   :Param("sometimes you don't want '...' but still want text to ")
   :Param("  format nicely in a not-too-wide block")
   :Param("length='12' maximum length of a word before")
{
   my ($handler, $string, $params) = @_;

   my $l = $params->{'length'};
   assert $l >= 1, "'length' parameter missing or invalid";

   while ($string =~ s/(\w{$l})(\w)/$1 $2/) { }

   return $string;
}
