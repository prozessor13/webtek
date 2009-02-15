use WebTek::Export qw( host );

sub host :Macro :Param(renders the hostname) {
   return "http://" . request->hostname;
}
