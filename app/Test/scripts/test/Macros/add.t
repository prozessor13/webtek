sub add_macro :Test {
   my $p = app::Page::Root->new;
   my $add = $p->can_macro('add')->($p, 'value1' => 12.5, 'value2' => 4.1);
   is $add, 16.6;
}
