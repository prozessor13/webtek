package WebTek::Macro;

# max wukits
# 12-02-09
#
# load a macro during runtime

use strict;

sub import {
   my ($class, @names) = @_;
   my $caller = caller;
   
   $class->load($_, $caller) foreach (@names);
}

sub load {
   my ($class, $name, $caller) = @_;
   $caller ||= caller;
   
   if (eval "use WebTek::Macro::$name; 1") {
      $name = "$name\_macro" if $class->can("$name\_macro");
      $class->init($name, $class->can($name), $caller);
   } else {
      log_error "WebTek::Macro::$name not found!" ;
   }
}

sub init {
   my ($class, $name, $coderef, $caller) = @_;
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
   WebTek::Util::make_method($class, $name, $wrapper, @$attributes);
}

1;