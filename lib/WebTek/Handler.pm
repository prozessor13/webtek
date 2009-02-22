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

make_accessor 'handlers';

# ----------------------------------------------------------------------------
# constructors
# ----------------------------------------------------------------------------

sub new {
   my $self = bless {}, shift;
   $self->handlers({});
   return $self;
}

# ----------------------------------------------------------------------------
# instance methods
# ----------------------------------------------------------------------------

sub handler {
   my ($self, $name, @handler) = @_;
   
   #... set handler
   return $self->handlers->{$name} = $handler[0] if @handler;
   #... get handler
   return $self->handlers->{$name} if $self->handlers->{$name};
   return $self->$name() if WebTek::Attributes->is_handler($self->can($name));

   throw "$self has no handler '$name'";
}

sub can_handler {
   my ($self, $name) = @_;
   
   return eval { $self->_handler($name) };
}

sub can_macro {
   my ($self, $name) = @_;
   
   my $coderef = $self->can("$name\_macro") || $self->can($name)
      || WebTek::Macro->load($name)
      && $self->can("$name\_macro") || $self->can($name);
   return WebTek::Attributes->is_macro($coderef) ? $coderef : undef;
}

sub can_filter {
   my ($self, $name) = @_;
   
   my $coderef = $self->can($name)
      || WebTek::Filter->load($name) && $self->can($name);
   return WebTek::Attributes->is_filter($coderef) ? $coderef : undef;
}

sub render_string {
   my ($self, $string, $params) = @_;
   
   my $compiled = WebTek::Compiler->compile($self, $string);
   return $compiled->($self, $params);
}

# ----------------------------------------------------------------------------
# internal methods
# ----------------------------------------------------------------------------

*_handler = \&handler;

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

sub _info {
   # FIXME
}

1;
