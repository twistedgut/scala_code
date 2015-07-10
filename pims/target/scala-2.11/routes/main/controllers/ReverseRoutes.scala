
// @GENERATOR:play-routes-compiler
// @SOURCE:/vagrant/conf/routes
// @DATE:Fri Jul 10 16:02:14 UTC 2015

import play.api.mvc.{ QueryStringBindable, PathBindable, Call, JavascriptLiteral }
import play.core.routing.{ HandlerDef, ReverseRouteContext, queryString, dynamicString }


import _root_.controllers.Assets.Asset

// @LINE:7
package controllers {

  // @LINE:21
  class ReverseAssets(_prefix: => String) {
    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:21
    def at(path:String, file:String): Call = {
    
      (path: @unchecked, file: @unchecked) match {
      
        // @LINE:21
        case (path, file) if path == "/public/swagger/json" && file == "main.json" =>
          implicit val _rrc = new ReverseRouteContext(Map(("path", "/public/swagger/json"), ("file", "main.json")))
          Call("GET", _prefix + { _defaultPrefix } + "swagger/")
      
        // @LINE:22
        case (path, file) if path == "/public/swagger/json" =>
          implicit val _rrc = new ReverseRouteContext(Map(("path", "/public/swagger/json")))
          Call("GET", _prefix + { _defaultPrefix } + "swagger/" + implicitly[PathBindable[String]].unbind("file", file))
      
        // @LINE:23
        case (path, file) if path == "/public/swagger/" && file == "index.html" =>
          implicit val _rrc = new ReverseRouteContext(Map(("path", "/public/swagger/"), ("file", "index.html")))
          Call("GET", _prefix + { _defaultPrefix } + "docs/")
      
        // @LINE:24
        case (path, file) if path == "/public/swagger/" =>
          implicit val _rrc = new ReverseRouteContext(Map(("path", "/public/swagger/")))
          Call("GET", _prefix + { _defaultPrefix } + "docs/" + implicitly[PathBindable[String]].unbind("file", file))
      
      }
    
    }
  
    // @LINE:27
    def versioned(file:Asset): Call = {
      implicit val _rrc = new ReverseRouteContext(Map(("path", "/public")))
      Call("GET", _prefix + { _defaultPrefix } + "assets/" + implicitly[PathBindable[Asset]].unbind("file", file))
    }
  
  }

  // @LINE:10
  class ReverseDistributionCentreController(_prefix: => String) {
    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:12
    def read(code:String): Call = {
      import ReverseRouteContext.empty
      Call("GET", _prefix + { _defaultPrefix } + "dc/" + implicitly[PathBindable[String]].unbind("code", dynamicString(code)))
    }
  
    // @LINE:11
    def create(): Call = {
      import ReverseRouteContext.empty
      Call("POST", _prefix + { _defaultPrefix } + "dc")
    }
  
    // @LINE:14
    def delete(code:String): Call = {
      import ReverseRouteContext.empty
      Call("DELETE", _prefix + { _defaultPrefix } + "dc/" + implicitly[PathBindable[String]].unbind("code", dynamicString(code)))
    }
  
    // @LINE:10
    def search(): Call = {
      import ReverseRouteContext.empty
      Call("GET", _prefix + { _defaultPrefix } + "dc")
    }
  
    // @LINE:13
    def update(code:String): Call = {
      import ReverseRouteContext.empty
      Call("PUT", _prefix + { _defaultPrefix } + "dc/" + implicitly[PathBindable[String]].unbind("code", dynamicString(code)))
    }
  
  }

  // @LINE:8
  class ReverseBoxesEndpoint(_prefix: => String) {
    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:8
    def create(): Call = {
      import ReverseRouteContext.empty
      Call("POST", _prefix + { _defaultPrefix } + "box")
    }
  
  }

  // @LINE:7
  class ReverseApplication(_prefix: => String) {
    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:7
    def index(): Call = {
      import ReverseRouteContext.empty
      Call("GET", _prefix)
    }
  
  }

  // @LINE:16
  class ReverseQuantityController(_prefix: => String) {
    def _defaultPrefix: String = {
      if (_prefix.endsWith("/")) "" else "/"
    }

  
    // @LINE:18
    def read(code:String): Call = {
      import ReverseRouteContext.empty
      Call("GET", _prefix + { _defaultPrefix } + "quantity/" + implicitly[PathBindable[String]].unbind("code", dynamicString(code)))
    }
  
    // @LINE:17
    def dec(code:String): Call = {
      import ReverseRouteContext.empty
      Call("PUT", _prefix + { _defaultPrefix } + "quantity/dec/" + implicitly[PathBindable[String]].unbind("code", dynamicString(code)))
    }
  
    // @LINE:16
    def inc(code:String): Call = {
      import ReverseRouteContext.empty
      Call("PUT", _prefix + { _defaultPrefix } + "quantity/inc/" + implicitly[PathBindable[String]].unbind("code", dynamicString(code)))
    }
  
  }


}