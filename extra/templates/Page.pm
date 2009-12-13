use base qw( app::Page::Page );

#... replace the parent page with your parent-page
use WebTek::Parent qw( <% appname %>::Page::Root );

# ---------------------------------------------------------------------------
# constructors (customize me!)
# ---------------------------------------------------------------------------

class method new_for_<% packagename_last_lower %>($path) :Path(<% packagename_last_lower %>) {
   my $self = $class->new;
   $self->path($path);
   return $self;
}
