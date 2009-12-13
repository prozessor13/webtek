package WebTek::Exception;

# max demmelbauer
# 29-03-06
#
# provides the following exceptions:
#   - WebTek::Exception::Redirect
#   - WebTek::Exception::ObjInvalid
#   - WebTek::Exception::PageInvalid
#   - WebTek::Exception::ModelInvalid
#   - WebTek::Exception::Assert

use overload '""' => \&to_string;

sub import { *{caller . '::throw'} = \&{'WebTek::Exception::throw2'} }

sub create {
   my ($class, $msg, %params) = @_;
   
   #... create obj
   my $self = !(ref $class) && bless \%params, $class;   
   $self->{msg} = $msg if $msg;

   #... create exception stack-information
   my $stack = $self->{stack} || [];
   my $i = 1;  # omit exception-call in stack-trace
   while (my @caller = caller($i++)) {
      next if ($caller[0] eq 'main');
      push @$stack, "$caller[1]: line $caller[2], \n";
   }
   $self->{stack} = $stack;
   
   return $self;
}

#... class method
sub throw { die shift->create(@_) }

#... global throw method (exported by WebTek::Globals)
sub throw2 { die WebTek::Exception->create(@_) }

sub msg { shift->{msg} }

sub to_string {
   my $self = shift;
   
   return (ref $self) . ": $self->{msg}\n" . join("", @{$self->{stack}});
}

package WebTek::Exception::Redirect;

our @ISA = qw( WebTek::Exception );

package WebTek::Exception::ObjInvalid;

our @ISA = qw( WebTek::Exception );

sub create {
   my ($class, $msg, $obj) = @_;

   return $class->SUPER::create($msg, obj => $obj);
}

sub obj { shift->{obj} }

package WebTek::Exception::ModelInvalid;

our @ISA = qw( WebTek::Exception::ObjInvalid );

sub model { shift->obj }

package WebTek::Exception::PageInvalid;

our @ISA = qw( WebTek::Exception::ObjInvalid );

sub page { shift->obj }

package WebTek::Exception::Assert;

our @ISA = qw( WebTek::Exception );

sub create {
   my ($class, $msg, $pkg, $fname, $line) = @_;
   
   my $message = "Assertion in $pkg, $fname, $line: $msg";
   return $class->SUPER::create($message, obj => $obj, msg2 => $msg);
}

sub msg { shift->{msg2} }

1;