
method test_macro :Test {
   my $if = WebTek::Handler->new->can_macro('if');
   ok $if;
}

method test_filter :Test {
   my $decode_url = WebTek::Handler->new->can_filter('decode_url');
   ok $decode_url;
}
