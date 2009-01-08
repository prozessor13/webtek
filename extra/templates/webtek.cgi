#!/usr/bin/env perl -I<% dir %>/lib -I<% dir %>/app

use strict;
use WebTek::Globals;
use WebTek::Engine::CGI;

#... init application
WebTek::App->init(
  'name' => '<% appname %>',
  'dir' => '<% appdir %>/<% appname %>',
  'env' => [],
  'pre-modules' => [],
  'post-modules' => [],
  'engine' => 'WebTek::Engine::CGI',
  'log_level' => WebTek::Logger::LOG_LEVEL_INFO(),
);

event->notify('request-begin');

eval {
   #... prepare request
   event->notify('request-prepare-begin');
   app->engine->prepare;
   # HINT set here the location if you use RewriteRules
   #      e.g. request->location('/')
   event->notify('request-prepare-end');

   #... dispatch request
   event->notify('request-dispath-begin');
   WebTek::Dispatcher->dispatch(<% appname %>::Page::Root->new);
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
