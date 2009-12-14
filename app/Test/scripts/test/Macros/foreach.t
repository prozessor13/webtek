
sub foreach_macro :Test {
   app->engine->prepare(language => 'en');
   my $h = WebTek::Handler->new;
   my $p = app::Page::Root->new;
   my $p1 = app::Page::Page1->new;
   $p1->handler('h', $h);
   throws_ok { $p->_macro('foreach') } qr/no list defined/;
   throws_ok { $p->_macro('foreach', {
      list => 'list',
   }) } qr/list not type of ARRAY/;
   throws_ok { $p->_macro('foreach', {
      list => [qw( a b c)],
   }) } qr/no template or do-block defined/;
   throws_ok { $p->_macro('foreach', {
      list => [qw( a b c)], do => 'do', template => 'template',
   }) } qr/both, template and do-block defined/;
   throws_ok { $h->_macro('foreach', {
      list => [qw( a b c)], template => 'template',
   }) } qr/handler can only render strings/;
   throws_ok { $p1->_macro('foreach', {
      list => [qw( a b c)], iterator => 'h', do => 'do',
   }) } qr/there exists already a handler for this iterator-name/;
   throws_ok { $p1->_macro('foreach', {
      list => [qw( a b c)], do => 'do',
   }) } qr/no iterator defined/;
   my $foreach = 
   ok $p->_macro('foreach', {
      list => [qw( a b c)], do => 'x<% param.h %>', iterator => 'h',
   }) eq 'xaxbxc';
   ok $p->_macro('foreach', {
      list => [['a'],['b'],['c']], do => 'x<% param.0 %>',
   }) eq 'xaxbxc';
   ok $p->_macro('foreach', {
      list => [$p1,$p1,$p1], do => 'x<% h.x %>', iterator => 'h',
   }) eq 'xxxxxx';
   ok $p->_macro('foreach', {
      list => [$p1,$p1,$p1], template => 'foreach', iterator => 'h',
   }) eq 'xxx';
}
