package WebTek::Handler;

# max demmelbauer
# 15-03-08
#
# superclass of all handlers (= callable from templates)

use strict;
use WebTek::Util qw( assert make_accessor );
use WebTek::Filter qw( ALL );
use WebTek::Compiler;
use WebTek::Exception;
use Scalar::Util qw( reftype );
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );

make_accessor 'handlers';

sub new {
   my $self = bless {}, shift;
   $self->handlers({});
   return $self;
}

sub _handler {
   my ($self, $name, @handler) = @_;
   
   #... set handler
   return $self->handlers->{$name} = $handler[0] if @handler;
   #... get handler
   return $self->handlers->{$name} if $self->handlers->{$name};
   return $self->$name() if WebTek::Attributes->is_handler($self->can($name));

   throw "$self has no handler '$name'";
}

sub _macro {
   my ($self, $name, $params) = @_;
   
   my $coderef = $self->can_macro($name) or throw "$self has no macro '$name'";
   return $coderef && $coderef->($self, %$params);
}

sub _filter {
   my ($self, $name, $string, $params) = @_;
   
   my $coderef = $self->can_filter($name);
   return $coderef && $coderef->($self, $string, $params);
}

*handler = \&_handler;

sub can_handler { eval { $_[0]->_handler($_[1]) } }

sub can_macro {
   my ($self, $name) = @_;
   
   my $coderef = $self->can("$name\_macro") || $self->can($name);
   return WebTek::Attributes->is_macro($coderef) ? $coderef : undef;
}

sub can_filter {
   my ($self, $name) = @_;
   
   my $coderef = $self->can("$name\_filter") || $self->can($name);
   return WebTek::Attributes->is_filter($coderef) ? $coderef : undef;
}

sub render_string {
   my ($self, $string, $params) = @_;
   
   my $compiled = WebTek::Compiler->compile($self, $string);
   return $compiled->($self, $params);
}

# ---------------------------------------------------------------------------
# standard macros
# ---------------------------------------------------------------------------

sub self_macro :Macro { $_[0] }

sub if_macro :Macro
   :Param(render param yes or no, as of the result of the condition)
   :Param(condition="some value")
   :Param(true="some text" render this text if the condition is true)
   :Param(false="some text" render this text if the condition is false)
{
   my ($self, %params) = @_;
   
   assert exists $params{'condition'}, "no condition defined!";
   assert
      exists $params{'true'} || exists $params{'false'},
      "no true or false param defined!";
   return $params{'condition'} ? $params{'true'} : $params{'false'};
}

sub equals_macro :Macro 
   :Param(equals to values and returns the strings 0 or 1)
   :Param(value1="abc")
   :Param(value2="abc")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} eq $params{'value2'} ? 1 : 0;
}

sub and_macro :Macro 
   :Param(combine two values with logical and)
   :Param(value1="abc")
   :Param(value2="abc")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} && $params{'value2'};
}

sub or_macro :Macro 
   :Param(combine two values with logical and)
   :Param(value1="abc")
   :Param(value2="abc")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} || $params{'value2'};
}

sub not_macro :Macro 
   :Param(combine two values with logical and)
   :Param(value="123")
{
   my ($self, %params) = @_;
   
   return not $params{'value'};
}

sub add_macro :Macro :Public
   :Param(numerical addition)
   :Param(value1="12.3")
   :Param(value2="385.1")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} + $params{'value2'};
}

sub negate_macro :Macro :Public
   :Param(value="12.3")
{
   my ($self, %params) = @_;
   
   return - $params{'value'};
}

sub nochange_macro :Macro :Public
   :Param(takes param and returns it, without change)
   :Param(useful for applying filters)
   :Param(value="abc")
{
   my ($self, %params) = @_;
   return $params{'value'};
}

sub or_macro :Macro 
   :Param(combine two values with logical or)
   :Param(value1="abc")
   :Param(value2="abc")
{
   my ($self, %params) = @_;
   
   return $params{'value1'} || $params{'value2'};
}

sub match_macro :Macro 
   :Param(combine two values with logical or)
   :Param(value="abc")
   :Param(regexp=".*")
{
   my ($self, %params) = @_;
   
   return $params{'value'} =~ /$params{'regexp'}/;
}

sub config_macro :Macro 
   :Param(render a value from an configfile)
   :Param(name="db" optional, default: webtek)
   :Param(key="user" key of the config part)
{
   my ($self, %params) = @_;

   return WebTek::Config::config($params{'name'})->get($params{'key'});
}

sub struct_macro :Macro 
   :Param(access a struct object)
   :Param(obj="{a=>123, b=>456}")
   :Param(get="a")
{
   my ($self, %params) = @_;

   return WebTek::Data::Struct::struct($params{'obj'})->get($params{'get'});
}

sub foreach_macro :Macro 
   :Param(list="<% some_list %>")
   :Param(iterator="iteratorname")
   :Param(do="some template code")
   :Param(template="list_item", alternativ to the do parameter you can define a template which shoud be rendered for each item)
{
   my ($self, %params) = @_;
   
   assert($params{'list'}, "no list defined");
   assert(reftype $params{'list'} eq 'ARRAY', "list not type of ARRAY");
   assert(
      !$self->can_handler($params{'iterator'}),
      "there exists already a handler for this iterator-name '" .
         $params{'iterator'} . "', please choose another iterator-name"
   );
   assert(
      ($params{'do'} or $params{'template'}),
      "no template or do-block defined!"
   );
   assert(
      !($params{'do'} and $params{'template'}),
      "both, template and do-block defined, please set only one of them!"
   );
   assert(
      (!$params{'template'} or $self->can('render_template')),
      "handler can only render strings, not templates"
   );

   my @output;
   my $p = {};
   foreach my $item (@{$params{'list'}}) {
      if (not ref $item) {
         assert($params{'iterator'}, "no iterator defined");
         $p = { $params{'iterator'} => $item };
      } elsif (ref $item eq 'HASH') {
         $p = $item;
      } elsif (ref $item eq 'ARRAY') {
         $p = { map { $_ => $item->[$_] } (0 .. scalar(@$item)-1) };
      } else {
         assert($params{'iterator'}, "no iterator defined");
         $self->handler($params{'iterator'}, $item);         
      }
      if ($params{'do'}) {
         push @output, $self->render_string($params{'do'}, $p);
      } else {
         push @output, $self->render_template($params{'template'}, $p);
      }
   }
   $self->handler($params{'iterator'}, undef);
   return join $params{'join'}, @output;
}

1;
