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
