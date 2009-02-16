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
