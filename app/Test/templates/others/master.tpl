<html>
<head>
   <title><% response.title %></title>
   <script src="<% static %>/prototype.js" type="text/javascript"></script>
   <script src="<% static %>/webtek.js" type="text/javascript"></script>
   <link rel="stylesheet" type="text/css" href="<% static %>/webtek.css">
</head>
<body>
   <p class="message" id="message" style="display:none"></p>
   <% response.body %>
   <script>setMessage(<% response.message | encode_js %>)</script>
</body>
</html>