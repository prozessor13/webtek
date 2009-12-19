package WebTek::Handler;

use WebTek::Config qw( config );

sub static :Macro { config->{static}{href} }

1;