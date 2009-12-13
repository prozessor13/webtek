#!/usr/bin/env perl -I/Users/max/Projects/WebTek2/lib -I/Users/max/Projects/WebTek2/app

use strict;
use WebTek::Globals;
use WebTek::Engine::CGI;

#... init application
WebTek::App->init(
  'name' => 'Test',
  'dir' => '/Users/max/Projects/WebTek2/app/Test',
  'env' => [],
  'pre-modules' => [],
  'post-modules' => [],
  'engine' => 'WebTek::Engine::CGI',
  'log_level' => WebTek::Logger::LOG_LEVEL_INFO(),
);

event->trigger('request-begin');

eval {
   #... prepare request
   event->trigger('request-prepare-begin');
   app->engine->prepare;
   # HINT set here the location if you use RewriteRules
   #      e.g. request->location('/')
   event->trigger('request-prepare-end');

   #... dispatch request
   event->trigger('request-dispath-begin');
   WebTek::Dispatcher->dispatch(Test::Page::Root->new);
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
