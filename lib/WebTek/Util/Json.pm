package WebTek::Util::Json;

use strict;
use WebTek::Exception;
use WebTek::Export qw( encode_json decode_json_or_die );

our $Loaded;

BEGIN {
   if    (eval "use JSON::XS (); 1") { $Loaded = "JSON::XS"; }
   elsif (eval "use JSON::PP (); 1") { $Loaded = "JSON::PP"; }
   else { die("Please install JSON::XS or JSON::PP"); }
}

sub encode_json {
   my $input = shift;
   return eval {
      $Loaded->new->utf8->allow_blessed->convert_blessed->encode($input);
   } or throw $@;
}

sub decode_json_or_die {
   my $input = shift;
   return eval {
      $Loaded->new->utf8->allow_blessed->convert_blessed->decode($input);
   } or throw $@;
}

1;

=head1 DESCRIPTION

Wraps the JSON::XS and JSON::PP modules.

JSON::XS is faster then JSON::PP, but cannot be installed on "pure-Perl" installations.
