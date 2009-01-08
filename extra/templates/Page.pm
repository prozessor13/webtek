use base qw( app::Page::Page );

#... replace the parent page with your parent-page
use WebTek::Parent qw( <% appname %>::Page::Root );

# ---------------------------------------------------------------------------
# constructors (customize me!)
# ---------------------------------------------------------------------------

sub new_for_<% packagename_last_lower %> :Path(<% packagename_last_lower %>) {
   my $class = shift;
   my $path = shift;    # string with path
   
   my $self = $class->new;
   $self->path($path);
   return $self;
}
