package WebTek::Exception;

# max demmelbauer
# 29-03-06

use overload '""' => \&to_string;

sub import {
   my $caller = caller;
   *{"$caller\::throw"} = \&{"WebTek::Exception::throw2"}
}

sub create {
   my $class_or_self = shift;
   my $msg = shift;       # exception message
   
   #... check if there is already an exception object
   unless (ref $class_or_self) { $class_or_self = bless {}, $class_or_self }
   
   #... set exception msg
   if ($msg) { $class_or_self->{'msg'} = $msg; }

   #... create exception stack-information
   my $stack = $class_or_self->{'stack'} || [];
   my $i = 1;  # omit exception-call in stack-trace
   while (my @caller = caller($i++)) {
      next if ($caller[0] eq 'main');
      push @$stack, "$caller[1]: line $caller[2], \n";
   }
   $class_or_self->{'stack'} = $stack;
   
   return $class_or_self;
}

#... class method
sub throw { die shift->create(@_) }

#... global throw method (exported by WebTek::Globals)
sub throw2 { die WebTek::Exception->create(shift) }

sub msg { shift->{'msg'} }

sub to_string {
   my $self = shift;
   
   return (ref $self) . ": $self->{'msg'}\n" . join("", @{$self->{'stack'}});
}

package WebTek::Exception::Redirect;

# this exception is called on an redirect

our @ISA = qw( WebTek::Exception );

package WebTek::Exception::ObjInvalid;

# this exception is called when an obj is invalid

our @ISA = qw( WebTek::Exception );

sub create {
   my $class_or_self = shift;
   my $msg = shift;     # exception message
   my $obj = shift;     # ref to the obj throwing the exception

   my $self = $class_or_self->SUPER::create($msg);
   $self->{'obj'} = $obj;
   
   return $self;
}

sub obj { shift->{'obj'} }

package WebTek::Exception::ModelInvalid;

# this exception is called when a model is invalid and wanted to save

our @ISA = qw( WebTek::Exception::ObjInvalid );

sub model { shift->obj }

package WebTek::Exception::PageInvalid;

# this exception is called when a page is invalid

our @ISA = qw( WebTek::Exception::ObjInvalid );

sub page { shift->obj }

package WebTek::Exception::Assert;

our @ISA = qw( WebTek::Exception );

sub create {
   my ($class_or_self, $msg, $pkg, $fname, $line) = @_;
   
   my $message = "Assertion in $pkg, $fname, $line: $msg";
   my $self = $class_or_self->SUPER::create($message);
   $self->{'obj'} = $obj;
   $self->{'msg2'} = $msg;
   
   return $self;
}

sub msg { shift->{'msg2'} }

1;