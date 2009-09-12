
sub error_macro :Test {
   my $p = app::Page::Root->new;
   $p->_errors({
      'e1' => 'msg1',
      'e2' => 'msg2',
   });
   my $errors = $p->_macro('errors', { 'language' => 'en' });
   is $errors, "msg2<br />msg1";
   my $errors = $p->_macro('errors', {
      'language' => 'en',
      'separator' => '\n',
   });
   is $errors, 'msg2\nmsg1';
   my $errors = $p->_macro('errors', {
      'keys' => 'e1,e2',
      'language' => 'en',
      'separator' => '',
   });
   is $errors, 'msg1msg2';
}
