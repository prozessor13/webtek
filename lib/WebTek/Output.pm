package WebTek::Output;

# max demmelbauer
# 08-05-06
#
# catches the STDOUT in Macro functions
# this code is based on Test::Output::Tie

use strict;

our $SharedInstance;

sub TIEHANDLE { bless [], $_[0] }

sub push {
   unless ($SharedInstance) { $SharedInstance = tie *STDOUT, __PACKAGE__ }
   push @$SharedInstance, '';
}

sub pop {
   my $pop = @$SharedInstance ? pop @$SharedInstance : '';
   unless (@$SharedInstance) { undef $SharedInstance; untie *STDOUT }
   return $pop;
}

sub PRINT {
    my ($self, @strings) = @_;
    $self->[scalar(@$self) - 1] .= join '', @strings;
}

sub PRINTF {
    my ($self, $format, @strings) = @_;
    $self->[scalar(@$self) - 1] .= sprintf($format, @strings);
}

sub FILENO {}

1;