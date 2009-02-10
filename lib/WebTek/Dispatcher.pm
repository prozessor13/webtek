package WebTek::Dispatcher;

# max demmelbauer
# 14-02-06
#
# process the request

use strict;
use WebTek::Cache;
use WebTek::Event qw( event );
use WebTek::Filter qw( ALL );
use WebTek::Logger qw( ALL );
use WebTek::Timing qw( timer_start timer_end );
use WebTek::Parent;
use WebTek::Session qw( session );
use WebTek::Request qw( request );
use WebTek::Response qw( response );
use WebTek::Exception;

$WebTek::Dispatcher::CurrentPage = undef;

sub dispatch {
   my ($class, $root) = @_; # $root isa WebTek::Page
   
   #... ask page-cache
   if (request->is_get
       and !session->user
       and !request->no_cache
       and !request->param->no_cache
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
   timer_start("generate pages");
   request->path(WebTek::Request::Path->new);
   my ($path, $action, $format) = $class->process_path(
      $class->decode_url(request->path_info),
      $root,
      request->path,
   );
   my $page = $path->page;
   timer_end("generate pages");

   #... remember things in request
   request->page($page);
   request->action($action);
   request->format($format) if $format;

   #... call the action
   event->notify('before-request-action', $page);
   event->notify(ref($page) . "-before-action-$action", $page);
   if ($action eq 'index' and $page->can_rest) {
      &_process_rest_request;
   } else {
      &_process_normal_request;
      session->save;
   }
   event->notify(ref($page) . "-after-action-$action", $page);
   event->notify('after-request-action', $page);
}

sub process_path {
   my ($class, $path_info, $page, $path) = @_;
   
   $path = $path || WebTek::Request::Path->new;
   push @$path, $page;
   my $action = "index";
   my $format = '';
   #... process path
   PATH: while ($path_info and $path_info ne '/') {
      #... check for an action
      if ($path_info =~ /^\/([^\/]+?)(\.(\w+))?$/ and $page->can_action($1)) {
         $action = $1;
         $format = $3;
         last;
      }
      #... check for a childpage
      foreach my $info (@{$page->_child_paths}) {
         my ($childpage, $constructor, $p, $regexp) = @$info;
         if (my @match = $path_info =~ /$regexp/) {
            # create child with matching path-part
            $WebTek::Dispatcher::CurrentPage = $page;
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
      $action = "";
      last;
   }

   $WebTek::Dispatcher::CurrentPage = undef;
   return ($path, $action, $format);
}

# --------------------------------------------------------------------------
# process normal request (GET and POST)
# --------------------------------------------------------------------------

sub _process_normal_request {
   my $page = request->page;
   my $action = request->action;

   #... check if the cancel-button is pressed
   if (request->is_post and request->param->cancel) {
      return eval { response->redirect($page->href) };
   }

   #... some helper methods
   my $call_action = sub {
      eval {
         #... call the page action
         if ($action and $page->can_action($action)) {
            if ($page->check_access('action' => $action)) {
               $page->$action();
            } else {
               $page->access_denied;
            }
         } else {
            log_debug("no action '$action' found in page '$page'");
            $page->not_found;
         }
         #... write response if necessary
         $page->render_page unless defined response->buffer;
      };
      return $@;
   };
   my $throw_error =
      sub { throw "error in $page during action '$action': $_[0]" };

   #... process action on page
   timer_start("process action");
   my $error = &$call_action;
   timer_end("process action");
   
   #... no error occoured
   return unless $error;
   #... throw the error if error is a SCALAR
   &$throw_error($error) unless ref $error;
   #... error is 'only' a redirect
   return if $error->isa('WebTek::Exception::Redirect');
   #... error is an ObjectInvalid Exception
   #... here we process the action again, but with is_post set to 0
   #... and set the response.message with the error-strings
   if ($error->isa('WebTek::Exception::ObjInvalid')) {
      event->notify('request-had-errors');
      #... if object is a model additionally copy error-information to the page
      if ($error->isa('WebTek::Exception::ModelInvalid')) {
         $page->_errors({ %{$page->_errors}, %{$error->model->_errors} });
      }
      log_debug("Dispatcher: ObjInvalid Exception: " . $page->errors);
      if (request->is_post) {
         request->method('GET');
         $page->has_errors(1);
         $error = &$call_action;
         return unless $error;
         return if $error->isa('WebTek::Exception::Redirect');
         &$throw_error($error);
      }
   }
   #... throw the error-message of the Exception
   &$throw_error($error);
}

# --------------------------------------------------------------------------
# process a REST request (GET, POST, PUT and DELETE)
# --------------------------------------------------------------------------

sub _process_rest_request {
   my $page = request->page;
   my $action = request->action;
   my $rest_action = lc(request->method);
   response->format(request->format || 'json');
   
   #... call action save
   timer_start("process rest action");
   eval {
      if ($page->check_access('action' => $rest_action)) {
         #... call rest action
         if ($page->can_action($rest_action)) {
            $page->$rest_action();
         } else {
            log_debug("no action '$rest_action' found in page '$page'");
            return $page->method_not_allowed;
         }
      } else {
         $page->access_denied;
      }
      #... write response if necessary
      if (request->is_post) { response->status(201) } # created
      $page->render_page unless defined response->buffer;
   };
   timer_end("process rest action");
   
   #... no error occoured
   return unless $@;
   #... error is 'only' a redirect
   return if ref($@) and $@->isa('WebTek::Exception::Redirect');
   
   #... set error response for SCALAR errors
   unless (ref $@) {
      $page->render_page({ 'error' => $@ })
   #... error is an ObjectInvalid Exception
   } elsif ($@->isa('WebTek::Exception::ObjInvalid')) {
      #... if object is a model additionally copy error-information to the page
      if ($@->isa('WebTek::Exception::ModelInvalid')) {
         $page->_errors({ %{$page->_errors}, %{$@->model->_errors} });
      }
      log_debug("Dispatcher: ObjInvalid Exception: " . $page->errors);
      $page->has_errors(1);
      $page->render_page($page->_errors)
   #... some other kind of error
   } else { $page->render_page($@) }
}

1;