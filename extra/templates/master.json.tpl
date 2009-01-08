<% if condition="<% request.param.callback %>"
   true="<% request.param.callback %>(<% response.body %>);"
   false="<% response.body %>"
%>