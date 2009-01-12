package WebTek::Page;

# max demmelbauer
# 21-02-06
#
# superclass of all pages

use strict;
use Class::ISA;
use WebTek::Util qw( assert make_accessor make_method slurp );
use WebTek::Html qw( ALL );
use WebTek::Filter qw( ALL );
use WebTek::Globals;
use WebTek::Message;
use WebTek::Compiler;
use Encode qw( encode_utf8 );
use Digest::MD5 qw( md5_hex );
use base qw( WebTek::Handler );

make_accessor('path', 'Macro');
make_accessor('_errors');
make_accessor('_suppress_errors');
make_accessor('has_errors', 'Public');

# ---------------------------------------------------------------------------
# constants
# ---------------------------------------------------------------------------

sub LOCATION { request->location }

sub FORM_ERROR_CLASS { 'formElementWithError' }

sub EVAL_CODE_IN_MACROS { 1 }

sub MASTER_TEMPLATE_HTML { '/others/master' }

sub MASTER_TEMPLATE_AJAX { '/others/master.ajax' }

sub MASTER_TEMPLATE_JSON { '/others/master.json' }

sub _INIT { 1 }

sub CHILD_ORDER { [] }

# ---------------------------------------------------------------------------
# page features
# ---------------------------------------------------------------------------

our %Paths = ();
our %ChildPaths = ();
our %Actions = ();
our %Macros = ();
our %Templates = ();
our %Messages = ();
our %Public = ();

# ---------------------------------------------------------------------------
# constructors
# ---------------------------------------------------------------------------

sub new {
   my $class = shift;
   
   my $self = $class->SUPER::new;
   $self->_errors({});
   $self->parent($WebTek::Dispatcher::CurrentPage);
   event->notify("$class-created", $self);
   
   return $self;
}

# ---------------------------------------------------------------------------
# sub default actions
# ---------------------------------------------------------------------------

sub _info :Action {
   my $self = shift;
   
   #... prepare information
   my @path = map {
      "<b>". ($_->path ? "/" . $_->path : "") . "</b><i><small>(" . a_tag({
         href => $_->href('action' => '_info'), display => ($_->page_name)
      }) . ")</small></i>"
   } @{request->path};
   my $paths = $self->_paths;
   my @paths = map { "<li>$_->[0] for <i>$_->[1]</i></li>" } @$paths;
   my @child_paths = map {
      "<li>$_->[1] with <i>$_->[2]</i> in $_->[0]</li>"
   } @{$self->_child_paths};
   my @actions = map { "<li>$_</li>" } @{$self->_actions};
   my $macros = $self->_macros;
   my @macros = ();
   foreach my $macro (@$macros) {
      my ($name, $params) = @$macro;
      my @params = map { "<li>$_</li>" } @$params;
      push @macros, "$name<small><ul> @params </ul></small>";
   }
   @macros = map {"<li>$_</li>"} @macros;
   #... render infomation
   response->write("<h2>-- " . (ref $self) . " --</h2>\n");
   response->write("path: <b>" . $self->LOCATION . "</b>");
   response->write(join("&nbsp;", @path)."\n");
   response->write("<h4>paths:</h4>\n");
   response->write("<ul> @paths </ul>\n");
   response->write("<h4>child paths:</h4>\n");
   response->write("<ul> @child_paths </ul>\n");
   response->write("<h4>actions:</h4>\n");
   response->write("<ul> @actions </ul>\n");
   response->write("<h4>macros:</h4>\n");
   response->write("<ul> @macros </ul>\n");
}

# ---------------------------------------------------------------------------
# helper methods
# ---------------------------------------------------------------------------

sub _init {
   my $class = shift;
   log_debug("$$: init page $class");
   
   #... extract code-attribute informations (for Path, Action Macro)
   my (@actions, @paths, @macros, @public);
   my @attributes = @{WebTek::Attributes->attributes_for_class($class)};
   foreach my $attrs (@attributes) {
      my ($coderef, $attributes) = @$attrs;
      my $subname = WebTek::Util::subname_for_coderef($class, $coderef);
      next unless ($subname);
      push @public, [$subname, $attributes] if grep { /^Public/ } @$attributes;
      if (grep { /^Action/ } @$attributes) {
         push @actions, $subname;
         #... create check-access logic
         if (my @c = grep {/^CheckAccess\(.+\)$/} @$attributes) {
            if ($c[0] =~ /^CheckAccess\((.+)\)$/) {
               my $sub = eval "sub { my \$self = \$_[0]; $1 }";
               my @a = grep { $_ eq 'Public' } @$attributes;
               make_method($class, "$subname\_check_access", $sub, @a);
               push @public, ["$subname\_check_access", \@a] if @a;
            }
         }
         #... create etag wrapper
         if (my @e = grep $_, map {/^ETag\((.+)\)$/ ? $1 : 0} @$attributes) {
            my @etags = map { eval "sub { my \$self = \$_[0]; $_ }" } @e;
            my $wrapper = sub {
               my $self = shift;
               my $etag = "ETag:" . join(",", map { $_->($self) } @etags);
               my $digest = md5_hex(encode_utf8($etag));
               response->header('ETag' => $digest);
               if (request->headers->{'If-None-Match'} eq $digest) {
                  log_debug(
                     "send not_modified because of ETag in $class\::$subname"
                  );
                  return $self->not_modified;
               } else {
                  $coderef->($self);
               }
            };
            #... save new macro mehtod
            WebTek::Util::make_method($class, $subname, $wrapper, @$attributes);
         }
         #... register event for page-cache
         if (grep { /^Cache/ } @$attributes) {
            my $exptime;
            foreach (@$attributes) { $exptime = $1 if /^Cache\((.*)\)$/ }
            event->register(
               'obj' => $class,
               'name' => "$class\-after-action-$subname",
               'method' => sub {
                  return if session->user
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
      } elsif (my @p = grep { /^Path/ } @$attributes) {
         foreach (@p) {
            if (/^Path\((.*)\)/) { push @paths, [$subname, $1, qr#^\/*($1)#] }
         }
      } elsif (grep { /^Macro/ } @$attributes) {
         my $params = [];
         foreach (grep {/^Param/} @$attributes) {
            if (/^Param\((.*)\)$/) { push @$params, $1 }
         }
         push @macros, [$subname, $params];
         #... create wrapper for macro print output
         my $wrapper = sub {
            my ($self, %params) = @_;

            WebTek::Output->push;
            my $out = $coderef->($self, %params);
            my $print = WebTek::Output->pop;
            return $print ? "$print$out" : $out;
         };
         #... create wrapper for macro cache
         if (grep { /^Cache/ } @$attributes) {
            my ($print_wrapper, $exptime) = ($wrapper, 1);
            foreach (@$attributes) { $exptime = $1 if /^Cache\((.*)\)$/ }
            $wrapper = sub {
               my ($self, %params) = @_;
               
               my $key = $self->cache_key($subname, %params);
               my $out = WebTek::Cache::cache()->get($key);
               return $out if defined $out;
               $out = $print_wrapper->($self, %params);
               WebTek::Cache::cache()->set($key, $out, $exptime);
               return $out;
            };
         }
         #... save new macro mehtod
         WebTek::Util::make_method($class, $subname, $wrapper, @$attributes);
      }
      if (grep { /^Cache/ } @$attributes) {
         foreach (grep { /^Cache/ } @$attributes) {
            WebTek::Cache::settings($coderef, $1) if (/^Cache\((.*)\)$/)
         }
      }
   }
   
   #... remember information from attributes
   $Actions{$class} = \@actions;
   $Paths{$class} = \@paths;
   $Macros{$class} = \@macros;
   $Public{$class} = \@public;
   #... (re)set template/message cache
   $Templates{$class} = {};
   $Messages{$class} = {};
   #... delete ChildPaths in parents, because they may changed
   if ($class->can('_parents')) {
      foreach ($class->_parents) { $ChildPaths{$_} = undef }      
      #... check if _parents is defined in superclass
      if ($class->_parents && not defined &{"$class\::_parents"}) {
         WebTek::Parent->set_parents($class, $class->_parents);
      }
   } else {
      WebTek::Util::may_make_method($class, "_parents", sub { () });
   }
}

sub cache_key {
   my $self = shift;
   
   return WebTek::Cache::key(
      ref($self), $self->path, $self->request->language, @_,
   );
}

sub parent :Handler {
   my ($self, $parent) = @_;
   my $class = ref $self;
   
   #... set parent from parameter
   if ($parent) {
      $self->{'parent'} = $parent
   
   #... try to create parent automatically
   } elsif (not $self->{'parent'} and $self->_parents) {
      foreach my $parent ($self->_parents) {
         if ($parent->can('new_from_child')) {
            $self->{'parent'} = $parent->new_from_child($self);
         #... lets try the 'new' constructor for Root Pages
         } elsif (not $parent->_parents) {
            $self->{'parent'} = $parent->new;
         }
         last if $self->{'parent'};
      }
      assert $self->{'parent'}, "cannot create parent of $class; ".
         "parent must have a 'new_from_child' method (or 'new' if Root)";
   }

   #... return parent
   return $self->{'parent'};
}

sub error_on { (shift->error_key_for(@_)) }

sub error_key_for {
   my ($self, $name) = (shift, shift);
   
   if (@_) {   # set error-key for name
      $self->has_errors(1);
      $self->_errors->{$name} = shift;
   }
   return $self->_errors->{$name};
}

sub not_found {
   my $self = shift;
   
   response->status(404);
   response->write('page not found for url <i>' . request->uri . '</i>');
}

sub not_modified {
   my $self = shift;
   
   response->status(304);
   response->write('');
}

sub method_not_allowed: Public {
   my $self = shift;
   
   response->status(405);
   response->write('method not allowed for url <i>' . request->uri . '</i>');
}

sub access_denied {
   my $self = shift;
   
   response->status(403);
   response->write('access_denied for action <i>' . request->action . '</i>');
}

sub paginator {
   my ($self, $id) = (shift, shift);

   assert $id, "no id defined!";
   if (@_) { $self->{'__paginators'}->{$id} = shift }
   return $self->{'__paginators'}->{$id};
}

sub paginate {
   my ($self, %params) = @_;
   
   assert $params{'id'}, "no id defined";
   
   my $paginator = WebTek::Paginator->new(
      %params,
      'page' => $params{'page'} || request->param->page || undef,
      'items_per_page' =>
         $params{'items_per_page'} || request->param->items_per_page,
   );
   
   $self->paginator($params{'id'}, $paginator);
   return wantarray ? ($paginator->items, $paginator) : $paginator->items;
}

# ---------------------------------------------------------------------------
# methods about page-features
# ---------------------------------------------------------------------------

# returns a list of paths for this page
# a typical result looks like this
# [
#     [ 'new_for_foo',  'foo', 'compiled regexp of foo' ]
#     [ 'new_for_foo_with_number', 'foo\d', 'compiled regexp of foo\d' ]
# ]
sub _paths {
   my $class = ref $_[0] || $_[0];

   my @paths = @{$Paths{$class}};
   foreach my $super (Class::ISA::super_path($class)) {
      next unless ($Paths{$super});
      my @super = ();
      foreach my $s (@{$Paths{$super}}) {
         unless (grep { $_->[0] eq $s->[0] } @paths) { push @super, $s; }
      }
      push @paths, grep { $class->can_path($_->[0]) } @super;
   }
   return \@paths;
}

# returns alist of child_paths for this page
# the child_paths are all paths of all children for this page
# a typical result looks like this
# [
#     [ 'Classname::Of::PageA', 'new_for_foo',  'foo', 'regexp of foo' ]
#     [ 'Classname::Of::PageB', 'new_for_number', '\d+', 'regexp of \d' ]
# ]
sub _child_paths {
   my $class = ref $_[0] || $_[0];
   
   if (defined($ChildPaths{$class})) { return $ChildPaths{$class}; }
   
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
      push @paths, map { [ $child, @$_ ] } @{$Paths{$child}}
   }
   #... sort paths
   #... paths starting with the most plain characters have the higest priority
   @paths = sort {
       my $lenA = ($a->[2] =~ /^(\w+)/) ? length($1) : 0;
       my $lenB = ($b->[2] =~ /^(\w+)/) ? length($1) : 0;
       return $lenB <=> $lenA;
   } @paths;
   #... remember and return child paths
   return $ChildPaths{$class} = \@paths;
}

# returns a arrayref with all action-names [ 'action1', 'action2' ]
sub _actions {
   my $class = ref $_[0] || $_[0];

   my @actions = @{$Actions{$class}};
   foreach my $super (Class::ISA::super_path($class)) {
      next unless ($Actions{$super});
      my @super = ();
      foreach my $s (@{$Actions{$super}}) {
         unless (grep { $_ eq $s } @actions) { push @super, $s; }
      }
      push @actions, grep { $class->can_action($_) } @super;
   }
   @actions = sort @actions;
   return \@actions;
}

# returns (or sets) a arrayref with all public methods
# a typical result looks like this
# [
#   [ 'action1', [@attributes] ],
#   [ 'macro1', [@attributes] ],
# ]
sub _public {
   my $class_or_self = shift;
   my $class = ref $class_or_self || $class_or_self;
   
   $Public{$class} = shift if @_;
   return $Public{$class};
}

# returns a list of macros
# a typical result looks like this
# [
#     [ 'macro-method-name1' , [ 'as="editor" render as editor'] ]
#     [ 'macro-method-name2' , [ 'as="link" render as link', 'param2' ] ]
# ]
sub _macros {
   my $class = ref $_[0] || $_[0];

   my @macros = @{$Macros{$class}};
   foreach my $super (Class::ISA::super_path($class)) {
      next unless ($Macros{$super});
      my @super = ();
      foreach my $s (@{$Macros{$super}}) {
         unless (grep { $_->[0] eq $s->[0] } @macros) { push @super, $s; }
      }
      push @macros, grep { $class->can_macro($_->[0]) } @super;
   }
   @macros = sort { $a->[0] cmp $b->[0] } @macros;
   return \@macros;
}

sub can_path {
   return $_[1] if WebTek::Attributes->is_path($_[0]->can($_[1]));
   return undef;
}
                
sub can_action {
   return $_[1] if WebTek::Attributes->is_action($_[0]->can($_[1]));
   return undef;
}
                
sub can_rest {  
   return $_[1] if WebTek::Attributes->is_rest($_[0]->can($_[1]));
   return undef;
}
                
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
   
   assert $params{'action'}, "no action defined!";
   return 0 unless $self->can_action($params{'action'});
   my $check_access = $self->can("$params{'action'}\_check_access");
   return 1 unless $check_access;
   my $access = eval { $check_access->($self) };
   if ($@) { log_debug "Page->check_access error in eval: $@" }
   return $access;
}

sub link :Macro
   :Param(href="xyz" link destination)
   :Param(display="xyz" link display name)
   :Param(all other params are forwarded into the a tag)
{
   my ($self, %params) = @_;
 
   $params{'display'} ||= $params{'href'};
   return a_tag(\%params);
}

sub link_ajax :Macro
   :Param(calls a link with an ajax request)
   :Param(href="xyz" link destination)
   :Param(display="xyz" link display name)
   :Param(update="htmlTagId" defines the id in which the result is pasted (with innerHTML), optional)
   :Param(replace="htmlTagId" defines the id in which the result is pasted (with outerHTML), optional)
   :Param(callback="functionname" defines the javascript function which is called after the request is completed)
{
   my ($self, %params) = @_;
   
   $params{'display'} ||= $params{'href'};
   my $js = $self->encode_html($self->encode_js({
      'method' => 'get',
      'url' => $params{'href'},
      'update' => $params{'update'},
      'replace' => $params{'replace'},
      'callback' => $params{'callback'},
   }));
   $params{'href'} = "javascript:ajaxHelper($js)";
   delete $params{'update'};
   delete $params{'replace'};
   delete $params{'callback'};
   return a_tag(\%params);
}

sub static :Macro
   :Param(render the src to a static file)
   :Param(filename="filename.ext" relative filename (from the static dir))
{
   my ($self, %params) = @_;
   
   my $fname = $params{'filename'} ? "/$params{'filename'}" : "";
   return config->{'static'}->{'href'} . $fname ;
}

sub href :Macro
   :Param(renders the url of this page)
   :Param(action="name" call an action of this page (optional))
{
   my ($self, %params) = @_;
   
   #... generate url
   my $href = $params{'action'};
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

sub href_incl_host :Macro
   :Param(renders the URL of the page, incl http://myhost.com/ etc.)
   :Param(action="name" call an action of this page (optional))
{
   my ($self, %params) = @_;
   my $url = $self->href(%params);
   # hack: what if not port 80? what if https? what if username/password?
   $url = "http://" . request->hostname . $url;
   return $url;
}

sub form :Macro
   :Param(render a form tag)
   :Param(action="action" optional, default action = response->action)
   :Param(method="post" optional, default = post)
   :Param(all other params are forwarded into the form tag)
{
   my ($self, %params) = @_;
   
   #... remember the form errors
   $self->{'__form_errors'} = $self->_suppress_errors ? undef : [];
   
   if ($params{'action'}) {
      $params{'action'} = $params{'action'} =~ /^\//
         ? $params{'action'}                             # absolute href
         : $self->href('action' => $params{'action'});   # relative href
   } else {
      $params{'action'} ||= response->action
         || $self->href('action' => request->action);
   }
   
   $params{'method'} ||= "post";
      
   return form_tag(\%params) . "<div>";
}

sub form_ajax :Macro
   :Param(submits the form with an ajax request)
   :Param(action="action" optional, default action = response->action)
   :Param(update="htmlTagId" defines the id in which the result is pasted (with innerHTML), optional)
   :Param(replace="htmlTagId" defines the id in which the result is pasted (with outerHTML), optional)
   :Param(callback="functionname" defines the javascript function which is called after the request is completed)
   :Param(ajax_param="value" defines extra parameters which are forwarded to the ajaxHelper function)
{
   my ($self, %params) = @_;

   #... remember the form errors
   $self->{'__form_errors'} = $self->_suppress_errors ? undef : [];
   
   #... create action href
   my $action = $params{'action'}
      || response->action || $self->href('action' => request->action);
   delete $params{'action'};
   #... prepare ajaxHelper params
   my $ajax = {
      'callback' => $params{'callback'},
      'update' => $params{'update'},
      'replace' => $params{'replace'},
      'url' => $action,
      'method' => 'post',
   };
   foreach (keys %params) {
      if ($_ =~ /^ajax_(.+)$/) {
         $ajax->{$1} = $params{$_};
         delete $params{$_};
      }
   }
   my $json = $self->encode_html($self->encode_js($ajax));
   my $param = '{parameters:Form.serialize(this),' . substr($json, 1);
   #... merge predefined onsubmit with ajaxHelper
   my $os = $params{'onsubmit'} ? "$params{'onsubmit'};" : "";   
   $params{'onsubmit'} = "${os}ajaxHelper($param); return false;";
   #... create form tag
   delete $params{'update'};
   delete $params{'replace'};
   delete $params{'callback'};
   return form_tag(\%params) . "<div>";
}

sub form_end :Macro
   :Param(render the form-end-tag and extends response.message with form error-information)
   :Param(message="msg2" define the response.message container, default="default")
{
   my $self = shift;
   my %params = @_;
   
   my $html = "</div></form>";
   #... may update the response->message with form error-information
   if ($self->{'__form_errors'} and @{$self->{'__form_errors'}}) {
      my $err = $self->errors('keys' => join ",", @{$self->{'__form_errors'}});
      if (my $msg = $params{'message'}) {
         response->message->$msg(response->message->$msg . $err);   
      } else {
         response->message(response->message . $err);            
      }
   }
   return $html;
}

sub img :Macro :Param(renders an image tag) {
   my ($self, %params) = @_;
   
   return img_tag(\%params);
}

sub input :Macro
   :Param(renders an form input tag)
   :Param(name="x" input-tag name)
   :Param(type="text" optional, default = text)
   :Param(value="value" optional, default = request->param->name or on submit-buttons the name)
   :Param(default_value="value" optional, set this value if no other value (request, handler, value) is defined)
   :Param(handler="handler" optional, with this Parameter the default value is also searched in the handler)
   :Param(all other params are forwarded into the form tag)
{
   my ($self, %params) = @_;

   $params{'type'} ||= 'text';
   return $self->render_form_field(\%params);
}

sub textarea :Macro
   :Param(render an textarea, all Parameter from the input macro works here)
{
   my ($self, %params) = @_;
   
   $params{'type'} = "textarea";
   return $self->render_form_field(\%params);
}

sub select :Macro
   :Param(renders a select box (=dropdown))
   :Param(values="value1,value2,value3" define the values)
   :Param(displays="display1,display2,display3" define the display (optional))
   :Param(selected="value2" set the selected option)
   :Param(separator="\|" define a regexp for the separator, default is ",")
{
   my ($self, %params) = @_;
   
   $params{'type'} = "select";
   my $sep = $params{'separator'} || ',';
   my @options = ();
   my @values = ref $params{'values'}
      ? @{$params{'values'}}
      : split($sep, $params{'values'});
   my @displays = ref $params{'displays'}
         ? @{$params{'displays'}}
         : split($sep, $params{'displays'});
   delete $params{'values'};
   delete $params{'displays'};
   for (my $i=0; $i<scalar(@values); $i++) {
      push @options, {
         'value' => $values[$i],
         'display' => exists $displays[$i] ? $displays[$i] : $values[$i]
      };
   }
   $params{'options'} = \@options;
   return $self->render_form_field(\%params);
}

sub select_from_list :Macro 
   :Param(renders a select box (=dropdown) from a list)
   :Param(list="&lt;% xyz_list %>" is the list of objects to be displayed)
   :Param(iterator="xyz" is the name of the variable containing the current value)
   :Param(value~"&lt;% xyz.id %>" is the internal scalar value to be used for each object)
   :Param(display~"&lt;% xyz.name | encode_html %>" is the value the user sees for each object)
   :Param(selected="&lt;% my_xyz %>" is the current object selected)
{
   my ($self, %params) = @_;
   
   assert($params{'list'}, "no list defined");
   assert($params{'iterator'}, "no iterator defined");
   assert(ref $params{'list'} eq 'ARRAY', "list not type of ARRAY");
   assert(
      !$self->can_handler($params{'iterator'}),
      "there exists already a handler for this iterator-name '" .
         $params{'iterator'} . "', please choose another iterator-name"
   );

   my @options = ();
   foreach my $item (@{$params{'list'}}) {
      $self->handler($params{'iterator'}, $item);
      push @options, {
         'value' => $self->render_string($params{'value'}),
         'display' => $self->render_string($params{'display'}),
      };
   };
  
   my $selected_str = undef;
   if ($params{'selected'}) {
      $self->handler($params{'iterator'}, $params{'selected'});
      $selected_str = $self->render_string($params{'value'});
   }

   $self->handler($params{'iterator'}, undef);

   delete $params{'list'};
   delete $params{'iterator'};
   delete $params{'selected'};
   delete $params{'display'};
   
   $params{'type'} = "select";
   $params{'options'} = \@options;
   $params{'value'} = $selected_str;
   
   return $self->render_form_field(\%params);
}

sub template :Macro
   :Param(name="x" name of the template (without .tpl))
   :Param(all other params are forwarded to the template)
{
   my ($self, %params) = @_;
   
   assert $params{'name'}, "no templatename defined in template macro";
   return $self->render_template($params{'name'}, \%params, 'die');
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
   $params{'language'} ||= session->language || request->language;
   #... render message
   my $key = WebTek::Cache::key($params{'language'}, $params{'key'});
   my $compiled = $Messages{ref $self}{$key};
   if (config->{'code-reload'} or not $compiled) {
      my $message = WebTek::Message->message(%params);
      $compiled = eval { WebTek::Compiler->compile($self, $message) };
      log_fatal "error compiling message $params{'key'}, details $@" if $@;
      $Messages{ref $self}{$key} = $compiled;
   }
   return $compiled->($self, \%params);
}

sub errors :Macro
   :Param(prints the errors of the page)
   :Param(separator="&lt;br /&gt;" define the separator between each error-msg (optional))
{
   my ($self, %params) = @_;

   my @keys = $params{'keys'}
      ? split ",", $params{'keys'}
      : keys %{$self->_errors};

   #... create the error msg
   my $sep = $params{'separator'} || "<br />";
   return join $sep, map {
      $self->message('key' => $self->error_key_for($_), %params)
   } @keys;
}

sub code :Macro
   :Param(executes perlcode and prints the result in the template)
   :Param(eval="some perl code")
   :Param(debug="1" returns the error-message if an error occoured, else an empty string will be returned)
{
   my ($self, %params) = @_;

   assert $self->EVAL_CODE_IN_MACROS, "no code eval allowed in page $self";
   assert $params{'eval'}, "param 'eval' not defined in code macro";

   my $html = eval "\{$params{'eval'}\}";
   return $@ if $@ and $params{'debug'};
   return $html;
}

sub host :Macro :Param(renders the hostname) {
   return "http://" . request->hostname;
}

sub pagination :Macro
   :Param(render the pagination navigation)
   :Param(container="tplname" optional tplname for the container)
   :Param(prev="tplname" optional tplname for the prev button)
   :Param(next="tplname" optional tplname for the next button)
   :Param(page="tplname" optional tplname for a page button)
   :Param(actual_page="tplname" optional tplname for the actual page button)
   :Param(filler="tplname" optional tplname for the filler tpl)
   :Param(padding="2" optional padding width)
{
   my ($self, %params) = @_;
   
   assert $params{'id'}, "no pagination id defined!";
   my $p = $self->paginator($params{'id'});
   
   #... check if there exists a paginator for this id
   return "" unless $p;
   #... dont display the paginator for only one page
   return "" if $p->last_page <= 1;

   #... set default templates and values
   $params{'prev'} = exists $params{'prev'}
      ? $params{'prev'}
      : '/others/pagination/previous_page';
   $params{'next'} = exists $params{'next'}
      ? $params{'next'}
      : '/others/pagination/next_page';
   $params{'page'} = exists $params{'page'}
      ? $params{'page'}
      : '/others/pagination/page';
   $params{'actual_page'} = exists $params{'actual_page'}
      ? $params{'actual_page'}
      : '/others/pagination/actual_page';
   $params{'filler'} = exists $params{'filler'}
      ? $params{'filler'}
      : '/others/pagination/filler';
   $params{'container'} = exists $params{'container'}
      ? $params{'container'}
      : '/others/pagination/container';
   $params{'padding'} ||= 2;
   
   my $pagination = "";
   
   #... create prev link
   if ($p->page > 1 and $params{'prev'}) {
      $pagination .= $self->
         render_template($params{'prev'}, { 'page' => $p->page - 1 });
   }
   #... create first page
   my $tpl = (1 == $p->page) ? $params{'actual_page'} : $params{'page'};
   $pagination .= $self->render_template($tpl, { 'page' => 1 });      
   #... create first filler
   if (($p->page - $params{'padding'}) > 2) {
      $pagination .= $self->render_template($params{'filler'});
   }
   #... create mid pages
   foreach my $i (2 .. ($p->last_page - 1)) {
      next if $i < ($p->page - $params{'padding'});
      next if $i > ($p->page + $params{'padding'});
      my $tpl = $i == $p->page ? $params{'actual_page'} : $params{'page'};
      $pagination .= $self->render_template($tpl, { 'page' => $i });      
   }
   #... create last filler
   if (($p->page + $params{'padding'}) < ($p->last_page - 1)) {
      $pagination .= $self->render_template($params{'filler'});
   }
   #... create last page
   $tpl = ($p->last_page == $p->page)
      ? $params{'actual_page'}
      : $params{'page'};
   $pagination .= $self->render_template($tpl, { 'page' => $p->last_page });      
   #... create next link
   if ($p->last_page > $p->page and $params{'next'}) {
      $pagination .= $self->
         render_template($params{'next'}, { 'page' => $p->page + 1 });
   }
   
   return $self->
      render_template($params{'container'}, { 'pagination' => $pagination });
}

# ---------------------------------------------------------------------------
# render
# ---------------------------------------------------------------------------

sub render_form_field {
   my ($self, $params) = @_;
   
   assert $params->{'name'}, "no form field name defined";
   assert $params->{'type'}, "no form field type defined";
   my ($name, $elm_name) = ($params->{'name'}, $params->{'name'});
   my $type = $params->{'type'};

   #... is the field for a handler
   my $h = $params->{'handler'} || $params->{'model'};
   my $handler = eval { $self->handler($h) };
   
   #... if yes, update the form field name with handler-information
   $params->{'name'} = $elm_name = "$h\___$name" if $h;
   delete $params->{'handler'};
   delete $params->{'model'};

   #... check for an error
   my $error = $handler ? $handler->error_on($name) : $self->error_on($name);
   if ($error and my $errors = $self->{'__form_errors'}) {
      push @$errors, $name
         if $type ne 'radio' or not grep { $name eq $_ } @$errors
   }

   #... handle a radio button (is it checked?)
   if ($type eq 'radio' and defined $params->{'value'}) {
      $params->{'checked'} = 'checked'
         if $params->{'value'} eq request->param->$elm_name
            or $handler and $handler->can($name)
            and $params->{'value'} eq $handler->$name();
   }

   #... find value
   unless (exists $params->{'value'}) {
      #... for submit buttons the value = name
      if ($type eq 'submit') {
         $params->{'value'} = $name;
      #... prefill with request value
      } elsif (defined request->param->$elm_name) {
         my @req_params = request->param->$elm_name;
         if (@req_params == 1) {
            $params->{'value'} = $req_params[0];
         } else {
            my $i = $self->{'__default_value_for_' . $elm_name} || 0;
            $params->{'value'} = $req_params[$i];
            $self->{'__default_value_for_' . $elm_name} = $i + 1;
         }
      #... prefill with handler value   
      } elsif ($handler) {
         my $sub = $name;
         if ($name =~ /(\w+)___(.+)$/) {   # check if name is a struct key
            $sub = $1;
            $params->{'path'} = $2;       # path of WebTek::Data::Struct
         }
         my $val = $handler->can($sub) ? $handler->$sub() : undef;
         $val = $val->to_string($params) if ref $val;
         if (length($val)) {
            $params->{'value'} = $val;
         } else {
            $params->{'value'} = $params->{'default_value'};
         }
         delete $params->{'path'};
      #... set empty
      } else {
         $params->{'value'} = $params->{'default_value'};
      }
   }
   delete $params->{'default_value'};
   if ($params->{'format_number'}) {
      my $f = { 'format' => $params->{'format_number'} };
      $params->{'value'} = $self->format_number($params->{'value'}, $f);
   }
   $params->{'value'} = $self->encode_html($params->{'value'});
   if (!length($params->{'value'}) or $type eq 'password') {
      delete $params->{'value'};
   } elsif ($type ne 'textarea') {
      $params->{'value'} = $self->encode_qq($params->{'value'});
   };

   #... on error update css class with error-class
   if ($error) {
      $params->{'class'} = $params->{'class'}
         ? "$params->{'class'} " . $self->FORM_ERROR_CLASS
         : $self->FORM_ERROR_CLASS;
   }

   #... render form field
   my $html = "";
   #... handle checkbox
   if ($type eq 'checkbox') {
      $html .= input_tag({
         'type' => 'hidden',
         'name' => $elm_name,
         'value' => ($params->{'value'} ? '1' : '0'),
      });
      $params->{'onclick'} =
         "this.form.$elm_name.value=this.checked?'1':'0';$params->{'onclick'}";
      $params->{'checked'} ||= 'checked' if $params->{'value'};
      delete $params->{'name'};
      $html .= input_tag($params);
   #... handle textarea
   } elsif ($type eq 'textarea') {
      delete $params->{'type'};
      $html .= textarea_tag($params);
   #... handle select boxes
   } elsif ($type eq 'select') {
      $params->{'selected'} = $params->{'value'} || $params->{'selected'};
      delete $params->{'value'};
      delete $params->{'type'};
      $html .= select_tag($params);
   #... handle all other
   } else {
      $html .= input_tag($params);
   }

   return $html;
}

sub render_page {
   my ($self, $data) = @_;  # data is an optional obj

   #... render for the clients accepted format
   my $method = "render_as_" . response->format;
   assert $self->can($method), "cannot find method $method in '$self'";
   $self->$method($data);
}

sub render_as_html {
   my ($self, $params) = @_; # params: hashref with additional template params

   timer_start("render_as_html");
  
   #... set action
   unless (response->action) {
      my $action = request->action eq 'index' ? '' : request->action;
      response->action($self->href('action' => $action));
   }
   #... set title
   unless (response->title) { response->title(request->uri) }
   #... set body
   unless (response->body) {
      response->body($self->render_template(request->action, $params));
   }
   
   request->is_ajax
      ? response->write($self->render_template($self->MASTER_TEMPLATE_AJAX))
      : response->write($self->render_template($self->MASTER_TEMPLATE_HTML));

   timer_end("render_as_html");
}

sub render_as_json {
   my ($self, $body) = @_;
   $body ||= response->body;    # obj with should be rendered
   
   assert $body, "render_as_json: no response body defined!";
   timer_start("render_as_json");
   response->content_type('text/javascript');
   response->body($self->encode_js($body));
   response->write($self->render_template($self->MASTER_TEMPLATE_JSON));
   timer_end("render_as_json");
}

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
   
   
   #... ask cache for the template
   my $tpl = $Templates{$class}->{$tplname};

   #... load language/env specific or 'normal' template
   #... search order is:
   #...   - de.index.env2.tpl
   #...   - de.index.env1.tpl
   #...   - index.env2.tpl
   #...   - index.env1.tpl
   #...   - de.index.tpl
   #...   - index.tpl
   if (config->{'code-reload'} or not $tpl) {
      timer_start "load and compile tpl: $tplname";
      my $file = $self->find_template($tplname);
      my $content = $file ? slurp($file) : "";
      my $compiled = eval { WebTek::Compiler->compile($self, $content) };
      log_fatal "error compiling template $file, details $@" if $@;
      $Templates{$class}->{$tplname} = $tpl = [$file, $compiled];
      timer_end "load and compile tpl: $tplname";
   }
   
   #... check if template-file is found
   unless ($tpl->[0]) {
      die "cannot find template $tplname for page $class" if $die;
      log_warning "cannot find template $tplname for page $class";
      return "";
   }
   
   #... render template
   my ($file, $compiled) = @$tpl;
   timer_start("render_template $file");
   $tpl = "<!-- template-begin: $file -->$tpl" if config->{'tpl-debug'};
   my $result = $compiled->($self, $params);
   $tpl = "$tpl<!-- template-end: $file -->" if config->{'tpl-debug'};
   timer_end("render_template $file");
   return $result;
}

1;
