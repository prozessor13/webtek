package WebTek::Attributes;

# max demmelbauer
# 21-02-06
#
# remember method attributs

use WebTek::Export qw( MODIFY_CODE_ATTRIBUTES );

my $AttributesForClass = {};
my $Attributes = {};

sub MODIFY_CODE_ATTRIBUTES {
   my ($class, $coderef, @attrs) = @_;

   $AttributesForClass->{$class} = [] unless $AttributesForClass->{$class};
   push @{$AttributesForClass->{$class}}, [$coderef, \@attrs];
   $Attributes->{$coderef} = \@attrs;
   return ();
}

sub is {
   my ($class, $coderef, $name) = @_;
   my $regexp = uc_first $name;
   return (grep { /$regexp/ } @{$Attributes->{$coderef}});
}

sub get { $Attributes->{$_[1]} }

sub attributes_for_class { $AttributesForClass->{ref $_[1] || $_[1]} || [] }

1;
