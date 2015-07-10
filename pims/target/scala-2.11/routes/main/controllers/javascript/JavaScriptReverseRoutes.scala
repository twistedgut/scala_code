
// @GENERATOR:play-routes-compiler
// @SOURCE:/vagrant/conf/routes
// @DATE:Fri Jul 10 16:02:14 UTC 2015

import play.api.routing.JavaScriptReverseRoute
import play.api.mvc.{ QueryStringBindable, PathBindable, Call, JavascriptLiteral }
import play.core.routing.{ HandlerDef, ReverseRouteContext, queryString, dynamicString }


import _root_.controllers.Assets.Asset

// @LINE:7
package controllers.javascript {
  import ReverseRouteContext.empty

  // @LINE:21
  class ReverseAssets(_prefix: => String) {

    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:21
    def at: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.Assets.at",
      """
        function(path,file) {
        
          if (path == """ + implicitly[JavascriptLiteral[String]].to("/public/swagger/json") + """ && file == """ + implicitly[JavascriptLiteral[String]].to("main.json") + """) {
            return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "swagger/"})
          }
        
          if (path == """ + implicitly[JavascriptLiteral[String]].to("/public/swagger/json") + """) {
            return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "swagger/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("file", file)})
          }
        
          if (path == """ + implicitly[JavascriptLiteral[String]].to("/public/swagger/") + """ && file == """ + implicitly[JavascriptLiteral[String]].to("index.html") + """) {
            return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "docs/"})
          }
        
          if (path == """ + implicitly[JavascriptLiteral[String]].to("/public/swagger/") + """) {
            return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "docs/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("file", file)})
          }
        
        }
      """
    )
  
    // @LINE:27
    def versioned: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.Assets.versioned",
      """
        function(file) {
          return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "assets/" + (""" + implicitly[PathBindable[Asset]].javascriptUnbind + """)("file", file)})
        }
      """
    )
  
  }

  // @LINE:10
  class ReverseDistributionCentreController(_prefix: => String) {

    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:12
    def read: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.DistributionCentreController.read",
      """
        function(code) {
          return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "dc/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("code", encodeURIComponent(code))})
        }
      """
    )
  
    // @LINE:11
    def create: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.DistributionCentreController.create",
      """
        function() {
          return _wA({method:"POST", url:"""" + _prefix + { _defaultPrefix } + """" + "dc"})
        }
      """
    )
  
    // @LINE:14
    def delete: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.DistributionCentreController.delete",
      """
        function(code) {
          return _wA({method:"DELETE", url:"""" + _prefix + { _defaultPrefix } + """" + "dc/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("code", encodeURIComponent(code))})
        }
      """
    )
  
    // @LINE:10
    def search: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.DistributionCentreController.search",
      """
        function() {
          return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "dc"})
        }
      """
    )
  
    // @LINE:13
    def update: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.DistributionCentreController.update",
      """
        function(code) {
          return _wA({method:"PUT", url:"""" + _prefix + { _defaultPrefix } + """" + "dc/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("code", encodeURIComponent(code))})
        }
      """
    )
  
  }

  // @LINE:8
  class ReverseBoxesEndpoint(_prefix: => String) {

    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:8
    def create: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.BoxesEndpoint.create",
      """
        function() {
          return _wA({method:"POST", url:"""" + _prefix + { _defaultPrefix } + """" + "box"})
        }
      """
    )
  
  }

  // @LINE:7
  class ReverseApplication(_prefix: => String) {

    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:7
    def index: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.Application.index",
      """
        function() {
          return _wA({method:"GET", url:"""" + _prefix + """"})
        }
      """
    )
  
  }

  // @LINE:16
  class ReverseQuantityController(_prefix: => String) {

    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:18
    def read: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.QuantityController.read",
      """
        function(code) {
          return _wA({method:"GET", url:"""" + _prefix + { _defaultPrefix } + """" + "quantity/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("code", encodeURIComponent(code))})
        }
      """
    )
  
    // @LINE:17
    def dec: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.QuantityController.dec",
      """
        function(code) {
          return _wA({method:"PUT", url:"""" + _prefix + { _defaultPrefix } + """" + "quantity/dec/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("code", encodeURIComponent(code))})
        }
      """
    )
  
    // @LINE:16
    def inc: JavaScriptReverseRoute = JavaScriptReverseRoute(
      "controllers.QuantityController.inc",
      """
        function(code) {
          return _wA({method:"PUT", url:"""" + _prefix + { _defaultPrefix } + """" + "quantity/inc/" + (""" + implicitly[PathBindable[String]].javascriptUnbind + """)("code", encodeURIComponent(code))})
        }
      """
    )
  
  }


}