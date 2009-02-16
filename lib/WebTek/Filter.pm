package WebTek::Filter;

# max wukits
# 12-02-09
#
# load a filter during runtime

use strict;
use WebTek::Logger qw( log_error );

sub import {
   my ($class, @names) = @_;
   my $caller = caller;
   
   $class->load($_, $caller) foreach (@names);
}

sub load {
   my ($class, $name, $caller) = @_;
   $caller ||= caller;
   
   if (eval "use WebTek::Filter::$name; 1") {
      my $sub = $class->can("$name\_filter") || $class->can($name);
      make_method($caller, $name, $sub, "Filter");
   } else {
      log_error "WebTek::Filter::$name not found!" ;
   }
}

1;