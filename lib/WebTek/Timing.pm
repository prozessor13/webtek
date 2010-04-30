package WebTek::Timing;

# max demmelbauer
#
# log timing-information

use strict;
use WebTek::Util qw( assert r );
use WebTek::Logger qw( ALL );
use WebTek::Config qw( config );
use WebTek::Event qw( event );
use WebTek::Export qw( timer_start timer_end );
require Time::HiRes;

our ($Timing, $Indent, $Log, $History, $Time, $LogLongRequest);

sub _init {
   event->register(
      'name' => 'request-begin',
      'method' => sub {
         &init;
         timer_start('request: ' . r->uri)
      },
   );
   event->register(
      'name' => 'request-end',
      'method' => sub {
         timer_end('request: ' . r->uri);
         my $time = Time::HiRes::time() - $Time;
         if (not $Log and $LogLongRequest and $time > $LogLongRequest) {
            log_info $_ foreach (@$History);
         }
      },
   );
   event->register(
      'name' => 'request-init-begin',
      'method' => sub { timer_start('init request') },
   );
   event->register(
      'name' => 'request-init-end',
      'method' => sub { timer_end('init request') },
   );   
}

sub timer_start {
   return unless $Log or $LogLongRequest;
   my $key = shift;

   $Indent++;
   $Timing->{$key} = Time::HiRes::time();
   my $info = ("| " x $Indent) . "timer start for '$key'";
   log_info($info) if $Log;
   push @$History, $info if $LogLongRequest;
}

sub timer_end {
   return unless $Log or $LogLongRequest;
   my $key = shift;

   assert $Timing->{$key}, "timing key '$key' not found!";
   my $time = Time::HiRes::time() - $Timing->{$key};
   my $info = ("| " x $Indent) . "timer end for '$key' in $time seconds";
   log_info($info) if $Log;
   push @$History, $info if $LogLongRequest;
   $Indent--;
}

sub init {
   $Log = config->{'log-time'};
   $LogLongRequest = config->{'log-long-request'};
   return unless $Log or $LogLongRequest;
   
   $Indent = 0;
   $Timing = {};
   $Time = Time::HiRes::time();
   $History = ["Long Request:\n"];
}

1;