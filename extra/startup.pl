# preload all apache2 libraries
use ModPerl::Util ();
use Apache2::Directive ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Connection ();
use Apache2::Log ();
use APR::Table ();
use ModPerl::Registry ();
use Apache2::Const -compile => ':common';
use APR::Const -compile => ':common';

# find all PerlResponseHandlers (exclusive the Debug::Handler)
$::WebTekHandlers = [];
sub find_handlers {
   my $hash = shift;
   foreach my $key (keys %$hash) {
      if ($key eq 'PerlResponseHandler') {
         next if $hash->{$key} eq 'Debug::Handler';
         if ($hash->{$key} =~ /^([\w\:]+)\s*(\w*)/) {
            my $sub = $2 || 'handler';
            push @{$::WebTekHandlers}, "$1\::$sub";
         }
      }
      if (ref $hash->{$key} eq 'HASH') {
         find_handlers($hash->{$key});
      }
   }
}
find_handlers(Apache2::Directive::conftree()->as_hash());

1;