package Test::Handler;

# handles a request from apache

use strict;
use WebTek::Globals;
use WebTek::Engine::ModPerl2;

sub handler : method {
   my ($class, $r) = @_; # $r - Apache2::RequestRec

   r($r); # set as global accessable
   
   #... init application
   WebTek::App->activate($r->dir_config('name')) or WebTek::App->init(
      'name' => $r->dir_config('name'),
      'dir' => $r->dir_config('dir'),
      'env' => [ split ",", $r->dir_config('env') ],
      'libraries' => [ split ",", $r->dir_config('libraries') ],
      'modules' => [ split ",", $r->dir_config('modules') ],
      'engine' => 'WebTek::Engine::ModPerl2',
   );
   
   event->trigger('request-begin');
   
   eval {
      #... prepare request
      event->trigger('request-prepare-begin');
      app->engine->prepare;
      event->trigger('request-prepare-end');

      #... dispatch request
      event->trigger('request-dispath-begin');
      app->engine->dispatch(Test::Page::Root->new);
      event->trigger('request-dispath-end');

      #... finalize request
      event->trigger('request-finalize-begin');
      app->engine->finalize;
      event->trigger('request-finalize-end');
   };

   #... report an error
   if (my $error = $@) {
      eval { event->trigger('request-had-errors') };
      $error .= $@ if $@;
      app->engine->error($error);
   }
   
   event->trigger('request-end');
   return Apache2::Const::OK;
}

1;
