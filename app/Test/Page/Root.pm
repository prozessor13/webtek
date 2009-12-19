use base qw( app::Page::Page );

use WebTek::Macro qw( static );

method index :Action {
   response->message('hallo');
}
