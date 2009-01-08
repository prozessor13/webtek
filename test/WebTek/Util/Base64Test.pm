package WebTek::Util::Base64Test;

use strict;
use Test::Unit::TestCase;
use WebTek::Util::Base64 qw( encode_base64 decode_base64 );

our @ISA = ('Test::Unit::TestCase');

sub test {
   my $self = shift;
   my $string = "abcd";
   my $base64 = encode_base64($string);
   my $result = decode_base64($base64);
   $self->assert_equals($string, $result);
}

1;