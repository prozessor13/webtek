package WebTek::Parent;

# max demmelbauer
# 05-03-06
#
# remember the parent-child relationships

use strict;
use WebTek::Util;
use WebTek::Module;
use WebTek::Attributes;

our %Children;
our %Parent;

sub import {
   my $class = shift;
   my @parents = grep { $_ ne 'root' } @_;
   my $caller = caller;

   #... remember parents in page
   WebTek::Util::may_make_method($caller, "_parents", sub { @parents });
   #... remember parents children
   $class->set_parents($caller, @parents);
   #... create public methods from parents
   foreach my $parent (@parents) {
      foreach (@{WebTek::Attributes->attributes_for_class($parent)}) {
         my ($coderef, $attributes) = @$_;
         if (grep { /Public/ } @$attributes) {
            my $name = WebTek::Util::subname_for_coderef($parent, $coderef);
            #... remove attributes which contains code
            my @a = grep { not /Cache|CheckAccess/ } @$attributes;
            #... create a method which points to the parent's page method
            WebTek::Util::may_make_method($caller, $name, sub {
               my $self = shift;
               return $self->parent->$name(@_);
            }, @a);
         }
      }
   }
}

sub set_parents {
   my ($class, $child, @parents) = @_;
   
   foreach my $parent (@parents) {
      WebTek::Module->require($parent);
      $Children{$parent} ||= [];
      unless (grep { $_ eq $child } @{$Children{$parent}}) {
         push @{$Children{$parent}}, $child;
      }
   }
}

sub children {
   my $page = shift;

   return $Children{$page} || [];
}

1;
