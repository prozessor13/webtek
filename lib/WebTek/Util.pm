package WebTek::Util;

# max demmelbauer
# 14-02-06
#
# some utilities
# INFO! this code is not much readable for performace reasons ;-)

use IO::Socket::INET;
use WebTek::Exception;
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );
use WebTek::Export qw( r stash assert make_method make_accessor );

my $R;      # global variable for the Apache2::RequestRec
my $Stash;  # global stash

sub r { $R = $_[0] if @_; $R }

sub stash { $Stash = $_[0] if @_; $Stash }

sub assert { WebTek::Exception::Assert->throw($_[1], caller) unless $_[0] }

# ---------------------------------------------------------------------------
# method utils
# ---------------------------------------------------------------------------

sub make_method {
   my ($class, $method, $sub, @attrs) = @_;
   $sub ||= sub { $_[0]->{$method} = $_[1] if @_ > 1; $_[0]->{$method} };
   *{"$class\::$method"} = $sub;
   WebTek::Attributes::MODIFY_CODE_ATTRIBUTES($class, $sub, @attrs) if @attrs;
}

sub may_make_method {
   my ($class, $method, $sub, @attrs) = @_;
   return if defined &{"$class\::$method"};
   make_method($class, $method, $sub, @attrs);
}

sub make_accessor {
   my $caller = caller;
   my ($method, @args) = @_;
   make_method($caller, $method, undef, @args);
}

sub subname_for_coderef {
   my ($class, $coderef) = @_;
   
   foreach my $sub (values %{"$class\::"}) {
      return *$sub{NAME} if *$sub{CODE} eq $coderef
   }
   return undef;
}

1;