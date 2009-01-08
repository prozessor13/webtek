package WebTek::Util::JsonTest;

use strict;
use Test::Unit::TestCase;
use WebTek::Util::Json qw( encode_json decode_json_or_die );

our @ISA = ('Test::Unit::TestCase');

sub test {
   my $self = shift;
   
   my $structure = { 'abc' => [ 'def' ] };
   my $json_string = encode_json($structure);
   my $result = decode_json_or_die($json_string);
   
   $self->assert(ref($result));
   $self->assert(ref($result->{'abc'}));
   $self->assert_equals(1, scalar(@{$result->{'abc'}}));
   $self->assert_equals('def', $result->{'abc'}->[0]);
}

1;