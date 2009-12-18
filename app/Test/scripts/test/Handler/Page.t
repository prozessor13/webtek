sub features :Test {
   my $p = app::Page::Root->new;
   ok $p->can_action('index');
}