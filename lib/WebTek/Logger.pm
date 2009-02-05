package WebTek::Logger;

# max demmelbauer
# 16-02-06
#
# do the logging stuff

use WebTek::Exception;
use WebTek::App qw( app );
use Date::Format qw( time2str );
use WebTek::Export qw( log_debug log_info log_warning log_error log_fatal );

sub LOG_LEVEL_FATAL { 4 }
sub LOG_LEVEL_ERROR { 3 }
sub LOG_LEVEL_WARNING { 2 }
sub LOG_LEVEL_INFO { 1 }
sub LOG_LEVEL_DEBUG { 0 }

sub log_debug { &log(LOG_LEVEL_DEBUG, $_[0]) }
sub log_info { &log(LOG_LEVEL_INFO, $_[0]) }
sub log_warning { &log(LOG_LEVEL_WARNING, $_[0]) }
sub log_error { &log(LOG_LEVEL_ERROR, $_[0]) }
sub log_fatal { &log(LOG_LEVEL_ERROR, $_[0]); throw $_[0] }

my $FH = STDERR;

sub file {
   my ($class, $fname) = @_;
   open $FH, ">> $fname" or log_error "cannot open logfile '$fname', $!";
}

sub log {
   my ($level, $msg) = @_;
   
   #... HACK!!! dont die on code compilation
   return unless $WebTek::App::App;
   #... check log-level
   return unless $level >= app->log_level;

   if (app->engine) {
      app->engine->log($level, $msg);
   } else {
      my $time = time2str("%Y-%m-%d %H:%M:%S", time);
      $level = (qw( debug info warning error fatal ))[$level];
      print $FH "[$time] [$level]: $msg\n";
   }
}

1;