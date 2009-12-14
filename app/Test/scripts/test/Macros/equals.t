
sub equals_macro :Test {
   my $p = app::Page::Root->new;
   my $equals = $p->_macro('equals', { value1 => 3, value2 => '3' });
   ok $equals;
   my $equals = $p->_macro('equals', { value1 => 'abc', value2 => 'abc' });
   ok $equals;
   my $equals = $p->_macro('equals', { value1 => 3, value2 => '4' });
   ok !$equals;
}
