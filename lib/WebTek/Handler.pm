package WebTek::Handler;

# max demmelbauer
# 15-03-08
#
# superclass of all handlers (= callable from templates)

use strict;
use WebTek::Compiler;
use WebTek::Exception;
use WebTek::Util qw( assert make_accessor );
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );

our %Info;

# ----------------------------------------------------------------------------
# constructors
# ----------------------------------------------------------------------------

sub new {
   my $class = shift;
   my $hash = shift || {};
   $hash->{_handlers} ||= {};
   return bless $hash, $class;
}

# ----------------------------------------------------------------------------
# instance methods
# ----------------------------------------------------------------------------

sub can_handler {
   my ($self, $name, $ignore_custom) = @_;
   
   my $code_handler = $self->_info('handler')->{$name};
   return $code_handler if $ignore_custom;
   return $code_handler || $self->{_handlers}{$name};
}

sub can_macro {
   my ($self, $name) = @_;
   my $info = $self->_info('macro');
   
   return $info->{$name} if exists $info->{$name};
   return $info->{$name} = eval { WebTek::Macro->load($name) };
}

sub can_filter {
   my ($self, $name) = @_;
   my $info = $self->_info('filter');
   
   return $info->{$name} if exists $info->{$name};
   return $info->{$name} = eval { WebTek::Filter->load($name) };
}

sub handler {
   my ($self, $name, @handler) = @_;
   
   if (@handler) {
      assert(!$self->can_handler($name, "ignore_custom"),
         "$self: cannot set handler $name, " .
         "because its already defined in code via the :Handler attribute"
      );
      $self->{_handlers}{$name} = $handler[0];
   }
   
   return $self->{_handlers}{$name};
}

sub render_string {
   my ($self, $string, $params) = @_;
   
   my $compiled = WebTek::Compiler->compile($self, $string);
   return $compiled->($self, $params);
}

# ----------------------------------------------------------------------------
# internal methods
# ----------------------------------------------------------------------------

sub _init {
   my $class = shift;
   WebTek::Logger::log_debug("$$: init handler $class");

   my ($h, $m, $f) = ({}, {}, {});
   $class->_reset(undef, { handler => $h, macro => $m, filter => $f });
   
   #... extract code-attribute informations
   foreach (@{WebTek::Attributes->attributes_for_class($class)}) {
      my ($coderef, $attributes) = @$_;
      my $name = WebTek::Util::subname_for_coderef($class, $coderef);
      next unless $name;
   
      #... process macros
      if (grep { /^Macro/ } @$attributes) {
         WebTek::Macro->init($name, $coderef);
         $name = $name =~ /^(\w+)_macro$/ ? $1 : $name;
         $m->{$name} = $coderef;
      #... process handler
      } elsif (grep { /^Handler/ } @$attributes) {
         $name = $name =~ /^(\w+)_handler$/ ? $1 : $name;
         $h->{$name} = $coderef;
      } elsif (grep { /^Filter/ } @$attributes) {
         $name = $name =~ /^(\w+)_filter$/ ? $1 : $name;
         $f->{$name} = $coderef;
      }
   }
}

sub _reset {
   my ($self, $type, $set) = @_;
   my $class = ref $self || $self;
   
   return $Info{$::appname}{$class}{$type} = $set if $type;
   return $Info{$::appname}{$class} = $set;
}

sub _info { $Info{$::appname}{ref $_[0] || $_[0]}{$_[1]} }

sub _handler {
   my ($self, $name) = @_;
   
   my $coderef = $self->can_handler($name, "ignore_custom");
   return $coderef->($self) if $coderef;
   return $self->{_handlers}{$name} or throw "$self has no handler $name";
}

sub _macro {
   my ($self, $name, $params) = @_;
   
   my $coderef = $self->can_macro($name) or throw "$self has no macro $name";
   return $coderef->($self, %$params);
}

sub _filter {
   my ($self, $name, $string, $params) = @_;
   
   my $coderef = $self->can_filter($name) or throw "$self has no filter $name";
   return $coderef && $coderef->($self, $string, $params);
}

1;
