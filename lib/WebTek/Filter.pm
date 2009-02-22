package WebTek::Filter;

# max wukits
# 12-02-09
#
# load a filter during runtime

use strict;
use WebTek::Util;
use WebTek::Loader;
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );

sub import {
   my ($class, @names) = @_;
   
    $class->load($_, caller) foreach (@names);
}

sub load {
   my ($class, $name, $caller) = @_;
   $caller ||= caller;
   
   WebTek::Loader->load("WebTek::Filter::$name");
   WebTek::Util::make_method($caller, $name, $class->can($name));
   $class->can($name);
}

1;