package WebTek::Util::Json;

use strict;
use WebTek::Exception;
use WebTek::Export qw( encode_json decode_json_or_die );

our $Loaded;

BEGIN {
   if    (eval 'use JSON::XS (); 1') { $Loaded = 'JSON::XS'; }
   elsif (eval 'use JSON::PP (); 1') { $Loaded = 'JSON::PP'; }
   else { die 'Please install JSON::XS or JSON::PP' }
}

sub encode_json {
   my ($input, $pretty) = @_;
   my $json = $Loaded->new->utf8->allow_blessed->convert_blessed->allow_nonref;
   $json->pretty(1) if $pretty;
   my $string = eval { $json->encode($input) };
   return $string unless $@;
   $@ =~ s/ at [\w\/]*WebTek\/Util\/Json\.pm.*//g;
   throw $@;
}

sub decode_json_or_die {
   my $input = shift;
   my $json = $Loaded->new->utf8->allow_blessed->convert_blessed->allow_nonref;
   my $struct = eval { $json->decode($input) };
   return $struct unless $@;
   $@ =~ s/ at [\w\/]*WebTek\/Util\/Json\.pm.*//sg;
   throw $@;
}

1;
