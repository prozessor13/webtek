var JsonRPCCounter = 0;
var JsonRPCStore = {};

/**
 * update the message paragraph with the given message
 *
 * @param msg String
 */
function setMessage(msg, id) {
   $(id || 'message').style.display = msg ? "block" : "none";
   $(id || 'message').update(msg);
}

/**
 * do an ajax request. This method is a wrapper for the prototype.js.
 * this method also follows redirects (which came from webtek).
 * the method takes an Object with the following params:
 *
 * @param url define the url for the request
 * @param callback define a callback after the request is finished (optional). 
 *    the callback function gets two arguments:
 *    request and an optional json-object from the header
 * @param update define a id which should be updated with
 *    the result of this request (optional)
 * @param replace define a id which should be replaced with
 *    the result of this request (optional)
 * @return Ajax.Request
 */
function ajaxHelper(param) {
   // prepare params
   var url = param.url; delete param.url;
   var callback = param.callback; delete param.callback;
   if (callback && typeof callback == "string") eval("callback = " + callback);
   var update = param.update; delete param.update;
   var replace = param.replace; delete param.replace;
   if (param.method == null) param.method = "get";
   // wrap the callback function to catch redirects
   param.onComplete = function(req, json) {
      var redirect = eval("req.getResponseHeader('X-Ajax-Redirect-Location')");
      if (redirect) location.href = redirect;
      if (callback) callback(req, json);
      if (update) $(update).update(req.responseText);
      if (replace) $(replace).replace(req.responseText);
   };
   // create an return the ajax request
   new Ajax.Request(url, param);
}

/**
 * does a json rpc call to url
 * 
 * @param url String
 * @param parameters Object
 * @param callback Function
 * @param timeout Number (optional)
 * @param callbackFunctionName String (optional)
 */
function jsonRpc(param) {
   var s = document.createElement("script"); 
   var id = "cb" + ++JsonRPCCounter;
   var timeout = param.timeout && window.setTimeout(function() { 
      jsonRpcCleanup(id, s); 
      param.callback(null); 
   }, param.timeout);
   JsonRPCStore[id] = function(data1, data2, data3) {
      if (timeout) clearTimeout(timeout);
      param.callback(data1, data2, data3);
      jsonRpcCleanup(id, s);
   };
   var p = "&" + $H(param.parameters).toQueryString();
   var callbackFkt = param.callbackFunctionName || 'callback';
   s.src = param.url + "?" + callbackFkt + "=JsonRPCStore." + id + p;
   document.body.appendChild(s);
}

function jsonRpcCleanup(id, s) {
   delete JsonRPCStore[id]; 
   setTimeout(function() { document.body.removeChild(s) }, 0); 
}