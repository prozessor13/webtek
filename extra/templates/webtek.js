function setMessage(msg, id) {
   id = "#" + (id || 'message');
   msg ? jQuery(id).show() : jQuery(id).hide();
   jQuery(id).html(msg);
}

/**
 * do an ajax request.
 * @param String url url for the request
 * @param String method request method. either <code>POST</code> or <code>GET</code>
 * @param Object data request parameters
 * @param Function callback? define a callback after the request is finished.
 *    the callback function gets two arguments: <ul>
 *       <li>XMLHttpRequest Object</li>
 *       <li>an optional Object created from the X-JSON header</li>
 *    </ul>
 * @param String update? id which should be updated with request-response
 * @param String replace? id which should be replaced with request-response
 */
function ajaxHelper(param) {
   // do callback-eval working with google closure compiler
   if (param.callback && typeof param.callback == "string") {
      window["_callback"] = param.callback;
      eval("window._callback = " + param.callback);
      param.callback = window["_callback"];
      window["_callback"] = null;
   }
   // create an return the ajax request
   return jQuery.ajax({
		url: param.url,
		data: param.data,
		type: param.method || 'GET',
		complete: function(req) {
         try {
            var redirect = req.getResponseHeader('X-Ajax-Redirect-Location');
            if (redirect) location.href = redirect;
   		   var json = req.getResponseHeader('X-JSON');
   		   if (json) json = String.parseJSON(json);
         } catch(e) { }
         if (param.callback) param.callback(req, json);
         if (param.update) jQuery(param.update).html(req.responseText);
         if (param.replace) jQuery(param.replace).html(req.responseText);
		}
	});
}