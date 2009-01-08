<script language="javascript">
function cometRequestJsonRpc() {
   var url = "<% host %>:<% param.port %><% param.location %>/<% param.event %>";
   var callback = function(event, obj) {
      <% param.callback %>(event, obj);
      setTimeout("cometRequestJsonRpc()", 0);
   };
   new jsonRpc({url: url, parameters: {}, callback: callback});
}
setTimeout("cometRequestJsonRpc()", 100);
</script>