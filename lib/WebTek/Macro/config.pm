package WebTek::Handler;

sub config_macro :Macro 
   :Info(render a value from an configfile)
   :Param(name="db" optional, default: webtek)
   :Param(key="user" key of the config part)
{
   my ($self, %params) = @_;

   return WebTek::Config::config($params{'name'})->get($params{'key'});
}

1;