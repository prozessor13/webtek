package <% appname %>::Handler;

# handles a request from apache

use strict;
use WebTek::Globals;
use WebTek::Engine::ModPerl2;

sub handler : method {
   my ($class, $r) = @_; # $r - Apache2::RequestRec

   r($r); # set as global accessable
   
   #... init application
   WebTek::App->activate($r->dir_config('name')) or WebTek::App->init(
      name => $r->dir_config('name'),
      dir => $r->dir_config('dir'),
      env => [ split ",", $r->dir_config('env') ],
      libraries => [ split ",", $r->dir_config('libraries') ],
      modules => [ split ",", $r->dir_config('modules') ],
      engine => 'WebTek::Engine::ModPerl2',
   );
   
   event->trigger(name => 'request-begin');
   
   eval {
      #... prepare request
      event->trigger(name => 'request-prepare-begin');
      app->engine->prepare;
      event->trigger(name => 'request-prepare-end');

      #... dispatch request
      event->trigger(name => 'request-dispath-begin');
      app->engine->dispatch(<% appname %>::Page::Root->new);
      event->trigger(name => 'request-dispath-end');

      #... finalize request
      event->trigger(name => 'request-finalize-begin');
      app->engine->finalize;
      event->trigger(name => 'request-finalize-end');
   };

   #... report an error
   if (my $error = $@) {
      eval { event->trigger(name => 'request-had-errors') };
      $error .= $@ if $@;
      app->engine->error($error);
   }
   
   event->trigger(name => 'request-end');
   return Apache2::Const::OK;
}

1;
