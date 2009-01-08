package WebTek::Attributes;

# max demmelbauer
# 21-02-06
#
# remember attributs of a page-classes
# can handle the following attributes:
#   Path, Action, Macro, Param, Public, Rest, Model, Filter, Cache, Handler

use WebTek::Export qw( MODIFY_CODE_ATTRIBUTES );

my $AttributesForClass = {};
my $Attributes = {};

# precompile regexps
my $is_path = qr/^Path/;
my $is_action = qr/^Action/;
my $is_rest = qr/^Rest/;
my $is_macro = qr/^Macro/;
my $is_filter = qr/^Filter/;
my $is_cache = qr/^Cache/;
my $is_handler = qr/^Handler/;
my $regexp;

sub MODIFY_CODE_ATTRIBUTES {
   my ($class, $coderef, @attrs) = @_;

   $AttributesForClass->{$class} = [] unless $AttributesForClass->{$class};
   push @{$AttributesForClass->{$class}}, [$coderef, \@attrs];
   $Attributes->{$coderef} = \@attrs;
   return ();
}

sub _has_attribute {
   return undef unless ($Attributes->{$_[1]});
   return (grep { /$regexp/ } @{$Attributes->{$_[1]}});
}

sub is_path { $regexp = $is_path; return &_has_attribute }
sub is_action { $regexp = $is_action; return &_has_attribute }
sub is_rest { $regexp = $is_rest; return &_has_attribute }
sub is_macro { $regexp = $is_macro; return &_has_attribute }
sub is_filter { $regexp = $is_filter; return &_has_attribute }
sub is_cache { $regexp = $is_cache; return &_has_attribute }
sub is_handler { $regexp = $is_handler; return &_has_attribute }

sub get { $Attributes->{$_[1]} }

sub attributes_for_class {
   my $proto = ref $_[1] || $_[1];     # classname or blessed referece

   return $AttributesForClass->{$proto} || [];
}

sub attributes { $Attributes }

1;
