
sub and_macro :Test {
   my $p = app::Page::Root->new;
   my $and = $p->_macro('and', { value1 => 1, value2 => 1 });
   ok $and;
   my $and = $p->_macro('and', { value1 => 0, value2 => 1 });
   ok !$and;
   my $and = $p->_macro('and', { value1 => 1, value2 => 0 });
   ok !$and;
}
