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
