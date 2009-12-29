use base qw( app::Page::Page );

use WebTek::Macro qw( static );

method get :Action :Rest {
   response->message('hallo');
}
