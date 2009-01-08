use base qw( app::Page::Page );

# every code here affects each page in this app,
# because every page has this page as a parent.
# this is may the right place to define a login/logout action

sub index :Action :Public { }
