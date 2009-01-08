package WebTek::Util::Base64;

use strict;
use WebTek::Export qw( encode_base64 decode_base64 );

our $Loaded;

BEGIN {
   if    (eval "use APR::Base64;     1") { $Loaded = "APR::Base64";  }
   elsif (eval "use MIME::Base64 (); 1") { $Loaded = "MIME::Base64"; }
   else { die("Please install APR::Base64 or MIME::Base64"); }
}

sub encode_base64 {
   my $input = shift;
   return APR::Base64::encode($input)  if ($Loaded eq 'APR::Base64');
   return MIME::Base64::encode($input) if ($Loaded eq 'MIME::Base64');
   die();
}

sub decode_base64 {
   my $input = shift;
   return APR::Base64::decode($input)  if ($Loaded eq 'APR::Base64');
   return MIME::Base64::decode($input) if ($Loaded eq 'MIME::Base64');
   die();
}

1;

=head1 DESCRIPTION

Wraps the APR::Base64 and MIME::Base64 systems.

APR::Base64 is part of the mod_perl2 system and is faster and should be used by default.
However it is not always available and cannot be made available by uploading to a pure-Perl hoster.
In such environments MIME::Base64 is usually available
(but it is also not pure-Perl, so also cannot be upLoaded, in case it is not available.)