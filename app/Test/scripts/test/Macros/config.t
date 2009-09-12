
sub config_macro :Test {
   my $p = app::Page::Root->new;
   my $lang = $p->_macro('config', { 'key' => 'default-language' });
   is $lang, 'en';
   my $charset = $p->_macro('config', { 'name' => 'db', 'key' => 'charset' });
   is $charset, 'utf-8';
}
