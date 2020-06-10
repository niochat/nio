var GetURL = function() {};
GetURL.prototype = {
  run: function(arguments) {
    arguments.completionFunction({"url": document.URL});
  }
};
var ExtensionPreprocessingJS = new GetURL;
