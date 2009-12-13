package WebTek::Timing;

# max demmelbauer
#
# log timing-information

use strict;
use WebTek::Util qw( assert );
use WebTek::Logger qw( ALL );
use WebTek::Config qw( config );
use WebTek::Event qw( event );
use WebTek::Export qw( timer_start timer_end );
require Time::HiRes;

our $Timing;
our $Indent;
our $Active;

sub _init {
   event->observe(
      name => 'request-begin',
      method => sub { &init; timer_start('request') },
   );
   event->observe(
      name => 'request-end',
      method => sub { timer_end('request') },
   );
   event->observe(
      name => 'request-init-begin',
      method => sub { timer_start('init request') },
   );
   event->observe(
      name => 'request-init-end',
      method => sub { timer_end('init request') },
   );   
}

sub timer_start {
   return unless $Active;
   my $key = shift;

   $Indent++;
   $Timing->{$key} = Time::HiRes::time();
   log_info(('| ' x $Indent) . "timer start for '$key'");
}

sub timer_end {
   return unless $Active;
   my $key = shift;

   assert($Timing->{$key}, "timing key '$key' not found!");
   my $time = Time::HiRes::time() - $Timing->{$key};
   log_info(('| ' x $Indent) . "timer end for '$key' in $time seconds");
   $Indent--;
}

sub init {
   if ($Active = config->{log_time}) {
      $Timing = {};
      $Indent = 0;
   }
}

1;