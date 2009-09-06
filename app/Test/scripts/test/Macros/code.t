
sub code_macro :Test {
   my $p = app::Page::Root->new;
   throws_ok { $p->can_macro('code')->($p) } qr/param 'eval' not defined/;

   my $code = $p->can_macro('code')->($p, 'eval' => '1 + 1');
   is $code, 2;

   my $code = $p->can_macro('code')->($p, 'eval' => '$self->xxx');
   ok !(defined $code);

   my $code = $p->can_macro('code')->($p, 'eval' => '$self->xxx', 'debug' => 1);
   like $code, qr/Can't locate object method "xxx" via package "Test::Page::Root/;

   my $p = app::Page::Page1->new;
   throws_ok { $p->can_macro('code')->($p, 'eval' => '1+1') } qr/no code eval allowed/;
}
