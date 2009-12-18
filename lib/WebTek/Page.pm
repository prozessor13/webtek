package WebTek::Page;

# max demmelbauer
# 21-02-06
#
# superclass of all pages

use strict;
use Class::ISA;
use WebTek::Util qw( assert make_accessor make_method );
use WebTek::Util::File qw( slurp );
use WebTek::Util::Html qw( ALL );
use WebTek::Filter;
use WebTek::Macro;
use WebTek::Globals;
use WebTek::Message;
use WebTek::Compiler;
use WebTek::Exception;
use Encode qw( encode_utf8 );
use Digest::MD5 qw( md5_hex );
use base qw( WebTek::Handler );

make_accessor 'path', 'Macro';
make_accessor '_errors';
make_accessor 'has_errors';

# ---------------------------------------------------------------------------
# constants
# ---------------------------------------------------------------------------

sub LOCATION { request->location }

sub FORM_ERROR_CLASS { 'formElementWithError' }

sub EVAL_CODE_IN_MACROS { 1 }

sub MASTER_TEMPLATE_HTML { '/others/master' }

sub MASTER_TEMPLATE_AJAX { '/others/master.ajax' }

sub MASTER_TEMPLATE_JSON { '/others/master.json' }

sub MASTER_TEMPLATE_ERROR { '/others/master.error' }

sub CHILD_ORDER { [] }

# ---------------------------------------------------------------------------
# cache templates and messages
# ---------------------------------------------------------------------------

our %Templates;
our %Messages;

# ---------------------------------------------------------------------------
# initialize page features
# ---------------------------------------------------------------------------

sub _init {
   my $class = shift;
   $class->SUPER::_init;
   log_debug("$$: init page $class");

   $Messages{$class} = {};
   $Templates{$class} = {};
   my $paths = $class->_reset('path', []);
   my $actions = $class->_reset('action', {});
   my $rest = $class->_reset('rest', {});
   
   #... extract code-attribute informations
   foreach (@{WebTek::Attributes->attributes_for_class($class)}) {
      my ($coderef, $attributes) = @$_;
      my $subname = WebTek::Util::subname_for_coderef($class, $coderef);
      next unless ($subname);
            
      #... process actions (create etag, cache and check-access logic)
      if (grep { /^Action/ } @$attributes) {
         $actions->{$subname} = $coderef;
         #... check if action is REST
         $rest->{$subname} = $coderef if grep {/^Rest$/} @$attributes;
         #... create check-access logic
         if (my @c = grep {/^CheckAccess\(.+\)$/} @$attributes) {
            if ($c[0] =~ /^CheckAccess\((.+)\)$/) {
               my $sub = eval "sub { my \$self = \$_[0]; $1 }";
               my @a = grep { $_ eq 'Public' } @$attributes;
               make_method($class, "$subname\_check_access", $sub, @a);
            }
         }
         #... create etag wrapper
         if (my @e = grep $_, map { /^ETag\((.+)\)$/ && $1 } @$attributes) {
            my @etags = map { eval "sub { my \$self = \$_[0]; $_ }" } @e;
            my $wrapper = sub {
               my $self = shift;
               my $etag = "ETag:" . join(",", map { $_->($self) } @etags);
               my $digest = md5_hex(encode_utf8($etag));
               response->header('ETag' => $digest);
               if (request->headers->{'If-None-Match'} eq $digest) {
                  my $method = "$class\::$subname";
                  log_debug("send not_modified because of ETag in $method");
                  response->no_cache(1);
                  return $self->not_modified;
               } else {
                  $coderef->($self);
               }
            };
            #... save new action mehtod
            WebTek::Util::make_method($class, $subname, $wrapper, @$attributes);
         }
         #... register event for page-cache
         if (grep { /^Cache/ } @$attributes) {
            my $exptime;
            foreach (@$attributes) { $exptime = $1 if /^Cache\((.*)\)$/ }
            event->observe(
               'scope' => $class,
               'name' => "after-action-$subname",
               'method' => sub {
                  return if not request->is_get
                     or session->user
                     or response->status ne 200
                     or response->no_cache
                     or request->no_cache
                     or request->param->no_cache;
                  my $root = request->path->Root;
                  my $key = $root->cache_key(request->unparsed_uri);
                  cache->set($key, response, $exptime || 60);
                  log_debug('set page-cache: ' . request->unparsed_uri);
               },
            );
         }

      #... process paths
      } elsif (my @p = grep $_, map { /^Path\((.*)\)/ && $1 } @$attributes) {
         push @$paths, [$subname, $_, qr#^\/*($1)#] foreach @p;

      }
   }
   
   #... delete ChildPaths in parents, because they may changed
   if ($class->can('_parents')) {
      foreach ($class->_parents) { $_->_reset('child_path') }      
      #... check if _parents is defined in superclass
      if ($class->_parents && not defined &{"$class\::_parents"}) {
         WebTek::Parent->set_parents($class, $class->_parents);
      }
   } else {
      WebTek::Util::may_make_method($class, '_parents', sub { () });
   }
}

# ---------------------------------------------------------------------------
# constructors
# ---------------------------------------------------------------------------

sub new {
   my $class = shift;
   
   my $self = $class->SUPER::new;
   $self->_errors({});
   event->trigger(obj => $class, name => "created", args => [ $self ]);
   
   return $self;
}

# ---------------------------------------------------------------------------
# call an action
# ---------------------------------------------------------------------------

sub do_action {
   my ($self, $action) = @_;
   
   #... update action name in case of REST
   my $is_rest = $action eq 'index' && $self->can_rest;
   $action = $is_rest if $is_rest;
   
   #... handle session for normal http requests
   unless ($is_rest) {
      my $session = config->{session}{class}->init;
      event->observe(
         name => 'request-finalize-end',   # is this dangerous?
         obj => $session,
         method => sub {
            $session->save;
            event->remove_all_on_object($session);
         },
      );
   }

   #... call action
   eval {
      return $self->not_found unless $action and $self->can_action($action);
      return $self->access_denied unless $self->check_access(action => $action);
      response->status(201) if $is_rest and request->is_post;
      $self->$action;
   };

   #... process error
   if (my $error = $@) {
      eval {
         #... handle scalar errors
         if (not ref $error) {
            throw $error;
         #... handle redirects
         } elsif ($error->isa('WebTek::Exception::Redirect')) {
            return;
         #... handle Invalid Obj
         } elsif ($error->isa('WebTek::Exception::ObjInvalid')) {
            $self->has_errors(1);
            $self->_errors({%{$self->_errors}, %{$error->obj->_errors}});
            log_debug "$self: ObjInvalid Exception: " . $self->errors;
            if (request->is_post and not $is_rest) {
               request->method('GET');
               $self->do_action($action);
            } else {
               response->status(500);               
            }
         #... handle all other errors
         } else {
            throw $error;
         }
      };
      throw "error in page $self and $action: $@" if $@;
   }
   
   #... set response
   $self->render_page unless defined response->buffer;
}

# ---------------------------------------------------------------------------
# helper methods
# ---------------------------------------------------------------------------

sub cache_key {
   my $self = shift;

   my @key = ref($self), $self->path, $self->request->language, @_;
   return WebTek::Cache::key(@key);
}

sub parent :Handler {
   my ($self, $parent) = @_;
   my $class = ref $self;
   
   #... set parent from parameter
   if ($parent) {
      $self->{parent} = $parent
   
   #... try to create parent automatically
   } elsif (not $self->{parent} and $self->_parents) {
      foreach my $parent ($self->_parents) {
         if ($parent->can('new_from_child')) {
            $self->{parent} = $parent->new_from_child($self);
         #... lets try the 'new' constructor for Root Pages
         } elsif (not $parent->_parents) {
            $self->{parent} = $parent->new;
         }
         last if $self->{parent};
      }
      assert $self->{parent}, "cannot create parent of $class; ".
         "parent must have a 'new_from_child' method (or 'new' if Root)";
   }

   #... return parent
   return $self->{parent};
}

sub paginator {
   my ($self, $id) = (shift, shift);

   assert $id, 'no id defined';
   $self->{__paginators}->{$id} = shift if @_;
   return $self->{__paginators}->{$id};
}

sub paginate {
   my ($self, %params) = @_;
   
   assert $params{id}, 'no id defined';
   
   my $paginator = WebTek::Paginator->new(
      %params,
      page => $params{page} || request->param->page || undef,
      items_per_page =>
         $params{items_per_page} || request->param->items_per_page,
   );
   
   $self->paginator($params{id}, $paginator);
   return wantarray ? ($paginator->items, $paginator) : $paginator->items;
}

sub error_on {
   my ($self, $name, @set) = @_;
   
   if (@set) {   # set error-key for name
      $self->has_errors(1);
      $self->_errors->{$name} = shift @set;
   }
   return $self->_errors->{$name};
}

# ---------------------------------------------------------------------------
# http error methods
# ---------------------------------------------------------------------------

sub not_found {
   my $self = shift;
   
   response->status(404);
   response->message('page not found');
}

sub not_modified {
   my $self = shift;
   
   response->status(304);
   response->message('not modified');
   response->body('');
}

sub method_not_allowed {
   my $self = shift;
   
   response->status(405);
   response->message('not allowed');
}

sub access_denied {
   my $self = shift;
   
   response->status(403);
   response->message('access_denied');
}

# ---------------------------------------------------------------------------
# methods about page-features
# ---------------------------------------------------------------------------

# returns alist of child_paths for this page
# the child_paths are all paths of all children for this page
# a typical result looks like this
# [
#     [ 'Classname::Of::PageA', 'new_for_foo',  'foo', 'regexp of foo' ]
#     [ 'Classname::Of::PageB', 'new_for_number', '\d+', 'regexp of \d' ]
# ]
sub child_paths {
   my $class = ref $_[0] || $_[0];

   return $class->_info('child_path') if $class->_info('child_path');
   
   #... find and order children
   my @children = sort {
      my ($ia, $ib) = (0, 0);
      for (my $i=0; $i<@{$class->CHILD_ORDER}; $i++) {
         $ia = $i if $a eq $class->CHILD_ORDER->[$i];
         $ib = $i if $b eq $class->CHILD_ORDER->[$i];
      }
      return $ia <=> $ib;
   } @{WebTek::Parent::children($class)};

   #... collect all paths
   my @paths = ();
   foreach my $child (@children) {
      push @paths, map { [ $child, @$_ ] } @{$child->_info('path')}
   }
   #... sort paths
   #... paths starting with the most plain characters have the higest priority
   @paths = sort {
       my $lenA = ($a->[2] =~ /^(\w+)/) ? length($1) : 0;
       my $lenB = ($b->[2] =~ /^(\w+)/) ? length($1) : 0;
       return $lenB <=> $lenA;
   } @paths;
   #... remember and return child paths
   return $class->_reset('child_path', \@paths);
}

sub can_action { $_[0]->_info('action')->{$_[1]} };

sub can_rest { $_[0]->_info('rest')->{$_[1]} };
          
# ---------------------------------------------------------------------------
# macros
# ---------------------------------------------------------------------------

sub page_name :Macro
   :Param(returns the last part (after ::) in ClassName e.g. "Root")
{
   my $class = ref $_[0] || $_[0];

   return $class =~ /::(\w+)$/ ? $1 : $class;
}

sub check_access :Macro :Param(action="index" action name) {
   my ($self, %params) = @_;
   
   assert $params{action}, "no action defined!";
   return 0 unless $self->can_action($params{action});
   my $check_access = $self->can("$params{action}\_check_access");
   return 1 unless $check_access;
   my $access = eval { $check_access->($self); 1 };
   if ($@) { log_debug "Page->check_access error in eval: $@" }
   return $access;
}

sub href :Macro
   :Param(renders the url of this page)
   :Param(action="name" call an action of this page (optional))
{
   my ($self, %params) = @_;
   
   #... generate url
   my $href = $params{action};
   my $page = $self;
   while ($page) {
      $href = $page->path . "/$href";
      $page = $page->parent;
   }
   $href = $self->LOCATION . $href;
   $href =~ s/\/\/+/\//;   # remove double slashes (when location only /)
   $href =~ s/\/+$//;      # remove trailing slash
   $href =~ s/\/index$//;  # remove useless /index
   return $href || '/';
}

sub message :Macro
   :Param(renders a message for the actual language (from user-agent or session.user))
   :Param(key="message-key" return the msg for key 'message-key')
   :Param(de="german message" define the message direct in the macro)
   :Param(en="english message" define the message direct in the macro)
   :Param(language="en" optional overwrite of the request or session langauge)
{
   my ($self, %params) = @_;
   
   #... find language for request
   $params{language} ||= request->language;
   #... render message
   my $k = $params{key} || $params{$params{language}};
   return '' unless $k;
   my $key = WebTek::Cache::key($params{language}, $k);
   $key .= ",$params{default}" if defined $params{default};
   my $compiled = $Messages{ref $self}{$key};
   if (config->{code_reload} or not $compiled) {
      my $message = WebTek::Message->message(%params);
      $compiled = eval { WebTek::Compiler->compile($self, $message) };
      log_fatal "error compiling message $params{key}, details $@" if $@;
      $Messages{ref $self}{$key} = $compiled;
   }
   return $compiled->($self, \%params);
}

sub template :Macro
   :Param(name="x" name of the template (without .tpl))
   :Param(all other params are forwarded to the template)
{
   my ($self, %params) = @_;
   
   assert $params{name}, 'no templatename defined in template macro';
   return $self->render_template($params{name}, \%params, 'die');
}

# ---------------------------------------------------------------------------
# page rendering
# ---------------------------------------------------------------------------

sub render_page {
   my ($self, $data) = @_;  # data is an optional obj

   #... render for the clients accepted format
   my $method = 'render_as_' . response->format;
   assert $self->can($method), "cannot find method $method in '$self'";
   $self->$method($data);
}

sub render_as_html {
   my $self = shift;

   timer_start('render_as_html');
   #... set defaults
   unless (response->action) {
      my $action = request->action eq 'index' ? '' : request->action;
      response->action($self->href(action => $action));
   }
   unless (response->title) { response->title(request->uri) }
   unless (response->body) {
      response->body($self->render_template(request->action));
   }
   #... write response
   if (request->is_ajax) {
      response->write($self->render_template($self->MASTER_TEMPLATE_AJAX));
   } elsif (response->status >= 300) {
      response->write($self->render_template($self->MASTER_TEMPLATE_ERROR));      
   } else {
      response->write($self->render_template($self->MASTER_TEMPLATE_HTML));
   }
   timer_end('render_as_html');
}

sub render_as_json {
   my $self = shift;
      
   timer_start('render_as_json');
   response->content_type('text/javascript');
   #... set/extend body
   my $body = response->body || {};
   $body->{error} ||= $self->_errors if response->status >= 300;
   $body->{status} ||= response->status;
   $body->{message} ||= response->status =~ /^2\d\d$/
      ? 'OK'
      : response->message;
   response->body($self->encode_js($body, { pretty => response->pretty }));
   #... write response as json
   response->write($self->render_template($self->MASTER_TEMPLATE_JSON));
   timer_end('render_as_json');
}

# ---------------------------------------------------------------------------
# templating
# ---------------------------------------------------------------------------

sub find_template {
   my ($self, $tplname) = @_;
   
   #... checks if a template exists
   sub _exists {
      my $fname = shift;

      # For example <template name="../OtherPage/index">:
      # If OtherPage is defined e.g. in another module
      # then "-e templates/MyPage/../OtherPage" fails as MyPage doesn't exist
      # But "-e templates/OtherPage" will succeed.
      # So remove any "some-dir/.."
      while ($fname =~ s|[^/]+/\.\.||) { }

      foreach my $dir (reverse @{app->dirs}) {
         return "$dir$fname" if -e "$dir$fname";
      }
   }
   
   #... find a template in Page's or its Parent's template directory
   sub _find {
      my ($self, $fname) = @_;
      
      #... check for absolute path
      return _exists "/templates$fname" if $fname =~ /^\//;

      #... check for relative path
      #    1) check the current page, then all of its parents
      #    2) for each page to check, check all its superclasses
      #    e.g. MyReportView extends ReportView; has parent ReportList,
      #    then templates could be in MyReportView, ReportView, or ReportList
      my $page = $self;
      while ($page) {
         my $class = ref $page;
         while ($class) {
            my $dir = $class;
            $dir =~ s/^\w+::\w+::(.*)$/$1/;
            $dir =~ s/::/\//g;
            if (my $file = _exists "/templates/$dir/$fname") { return $file }
            no strict 'refs';
            my @isa = @{"$class\::ISA"};
            $class = $isa[0];
         }
         $page = $page->parent;
      }
      
      #... check templates root dir
      return _exists "/templates/$fname";
   }
   
   #... load language/env specific or 'normal' template
   #... search order is:
   #...   - de.index.env2.tpl
   #...   - de.index.env1.tpl
   #...   - index.env2.tpl
   #...   - index.env1.tpl
   #...   - de.index.tpl
   #...   - index.tpl
   my ($language, $fname, $file) = (request->language, "$tplname.tpl");
   foreach my $suffix (reverse @{app->env}, app->name) {
      my $fname = "$tplname.$suffix.tpl";
      $file = $self->_find("$language.$fname") || $self->_find($fname);
      last if $file;
   }
   $file ||= $self->_find("$language.$fname") || $self->_find($fname);
   
   return $file;
}

sub render_template {
   my ($self, $tplname, $params, $die) = @_;
   my $class = ref $self;

   #... get template
   my $tpl = $Templates{$class}->{$tplname};
   if (config->{code_reload} or not $tpl) {
      timer_start "load and compile tpl: $tplname";
      my $file = $self->find_template($tplname);
      my $content = $file ? slurp($file) : '';
      my $compiled = eval { WebTek::Compiler->compile($self, $content) };
      log_fatal "error compiling template $file, details $@" if $@;
      $Templates{$class}->{$tplname} = $tpl = [$file, $compiled];
      timer_end "load and compile tpl: $tplname";
   }
   
   #... check if template is found
   unless ($tpl->[0]) {
      die "cannot find template $tplname for page $class" if $die;
      log_warning "cannot find template $tplname for page $class";
      return '';
   }
   
   #... render template
   my ($file, $compiled) = @$tpl;
   timer_start("render_template $file");
   $tpl = "<!-- template-begin: $file -->$tpl" if config->{tpl_debug};
   my $result = $compiled->($self, $params);
   $tpl = "$tpl<!-- template-end: $file -->" if config->{tpl_debug};
   timer_end("render_template $file");
   return $result;
}

1;
