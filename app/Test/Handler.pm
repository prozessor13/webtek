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
      'pre-modules' => [ split ",", $r->dir_config('pre-modules') ],
      'post-modules' => [ split ",", $r->dir_config('post-modules') ],
      'engine' => 'WebTek::Engine::ModPerl2',
   );
   
   event->notify('request-begin');
   
   eval {
      #... prepare request
      event->notify('request-prepare-begin');
      app->engine->prepare;
      event->notify('request-prepare-end');

      #... dispatch request
      event->notify('request-dispath-begin');
      app->engine->dispatch(Test::Page::Root->new);
      event->notify('request-dispath-end');

      #... finalize request
      event->notify('request-finalize-begin');
      app->engine->finalize;
      event->notify('request-finalize-end');
   };

   #... report an error
   if (my $error = $@) {
      eval { event->notify('request-had-errors') };
      $error .= $@ if $@;
      app->engine->error($error);
   }
   
   event->notify('request-end');
   return Apache2::Const::OK;
}

1;
