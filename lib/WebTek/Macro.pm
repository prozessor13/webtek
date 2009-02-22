package WebTek::Macro;

# max wukits
# 12-02-09
#
# load a macro during runtime

use strict;
use WebTek::Util;
use WebTek::Loader;
use WebTek::Exception;

sub import {
   my ($class, @names) = @_;
   
   $class->load($_) foreach (@names);
}

sub load {
   my ($class, $name) = @_;

   if (WebTek::Loader->load("WebTek::Macro::$name;")) {
      foreach my $c ('WebTek::Handler', 'WebTek::Page') {
         if (my $coderef = $c->can("$name\_macro") || $c->can($name)) {
            $class->init($c, $coderef);
            return $coderef;
         }
      }
   }
   throw "WebTek::Macro::$name not found!";
}

sub init {
   my ($class, $handler, $coderef) = @_;
   my $name = WebTek::Util::subname_for_coderef($handler, $coderef);
   my $attributes = WebTek::Attributes->attributes->{$coderef};
   
   #... create wrapper for macro print output
   my $wrapper = sub {
      my ($self, %params) = @_;

      WebTek::Output->push;
      my $out = $coderef->($self, %params);
      my $print = WebTek::Output->pop;
      return $print ? "$print$out" : $out;
   };
   
   #... create wrapper for macro cache
   if (grep { /^Cache/ } @$attributes) {
      my ($print_wrapper, $exptime) = ($wrapper, 1);
      foreach (@$attributes) { $exptime = $1 if /^Cache\((.*)\)$/ }
      $wrapper = sub {
         my ($self, %params) = @_;
         
         my $key = $self->cache_key($name, %params);
         my $out = WebTek::Cache::cache()->get($key);
         return $out if defined $out;
         $out = $print_wrapper->($self, %params);
         WebTek::Cache::cache()->set($key, $out, $exptime);
         return $out;
      };
   }
   
   #... save new macro mehtod
   WebTek::Util::make_method($handler, $name, $wrapper, @$attributes);
}

1;