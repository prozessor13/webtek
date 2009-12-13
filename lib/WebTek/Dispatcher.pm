package WebTek::Dispatcher;

# max demmelbauer
# 14-02-06
#
# process the request

use strict;
use WebTek::Parent;
use WebTek::Exception;
use WebTek::Event qw( event );
use WebTek::Request qw( request );
use WebTek::Logger qw( log_debug );
use WebTek::Response qw( response );
use WebTek::Filter qw( decode_url );
use WebTek::Timing qw( timer_start timer_end );
require WebTek::Cache;

sub dispatch {
   my ($class, $root) = @_; # $root isa WebTek::Page
   
   #... ask page-cache
   if (request->is_get
       and not request->no_cache
       and not request->param->no_cache
       and (my $response = WebTek::Cache::cache()->
         get($root->cache_key(request->unparsed_uri))
   )) {
      response->status($response->status);
      response->headers($response->headers);
      response->buffer($response->buffer);
      response->content_type($response->content_type);
      log_debug('found page-cache: ' . request->unparsed_uri);
      return;
   }
   
   #... create page structure
   timer_start('generate pages');
   request->path(WebTek::Request::Path->new);
   my ($path, $action, $format) = $class->process_path(
      $class->decode_url(request->path_info), $root, request->path
   );
   my $page = $path->page;
   timer_end('generate pages');

   #... remember things in request
   request->page($page);
   request->action($action);
   request->format($format) if $format;

   #... call the action
   event->trigger(name => 'before-action', args => [ $page, $action ]);
   $page->do_action($action);
   event->trigger(name => 'after-action', args => [ $page, $action ]);
}

sub process_path {
   my ($class, $path_info, $page, $path) = @_;
   
   $path = $path || WebTek::Request::Path->new;
   push @$path, $page;
   my $action = 'index';
   my $format = '';
   #... process path
   PATH: while ($path_info and $path_info ne '/') {
      #... check for an action
      if ($path_info =~ /^\/([^\/]+?)(\.(\w+))?$/ and $page->can_action($1)) {
         ($action, $format) = ($1, $3);
         last;
      }
      #... check for a childpage
      foreach my $info (@{$page->child_paths}) {
         my ($childpage, $constructor, $p, $regexp) = @$info;
         if (my @match = $path_info =~ /$regexp/) {
            # create child with matching path-part
            my $child = $childpage->$constructor(@match);
            if ($child and my $child_path = $child->path) {
               $child->parent($page);
               $page = $child;
               $child_path =~ s/(\W)/'\x{'.sprintf("%02x", ord($1)).'}'/eg;
               $path_info =~ s/\/?$child_path//;   # remove path-part
               push @$path, $page;
               next PATH;
            }
         }
      }
      #... path cannot processed
      $action = '';
      last;
   }

   return ($path, $action, $format);
}

1;