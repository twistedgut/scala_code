
// @GENERATOR:play-routes-compiler
// @SOURCE:/vagrant/conf/routes
// @DATE:Fri Jul 10 16:02:14 UTC 2015

package router

import play.core.routing._
import play.core.routing.HandlerInvokerFactory._
import play.core.j._

import play.api.mvc._

import _root_.controllers.Assets.Asset

object Routes extends Routes

class Routes extends GeneratedRouter {

  import ReverseRouteContext.empty

  override val errorHandler: play.api.http.HttpErrorHandler = play.api.http.LazyHttpErrorHandler

  private var _prefix = "/"

  def withPrefix(prefix: String): Routes = {
    _prefix = prefix
    router.RoutesPrefix.setPrefix(prefix)
    
    this
  }

  def prefix: String = _prefix

  lazy val defaultPrefix: String = {
    if (this.prefix.endsWith("/")) "" else "/"
  }

  def documentation: Seq[(String, String, String)] = List(
    ("""GET""", prefix, """controllers.Application.index"""),
    ("""POST""", prefix + (if(prefix.endsWith("/")) "" else "/") + """box""", """controllers.BoxesEndpoint.create"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """dc""", """controllers.DistributionCentreController.search"""),
    ("""POST""", prefix + (if(prefix.endsWith("/")) "" else "/") + """dc""", """controllers.DistributionCentreController.create"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """dc/$code<[^/]+>""", """controllers.DistributionCentreController.read(code:String)"""),
    ("""PUT""", prefix + (if(prefix.endsWith("/")) "" else "/") + """dc/$code<[^/]+>""", """controllers.DistributionCentreController.update(code:String)"""),
    ("""DELETE""", prefix + (if(prefix.endsWith("/")) "" else "/") + """dc/$code<[^/]+>""", """controllers.DistributionCentreController.delete(code:String)"""),
    ("""PUT""", prefix + (if(prefix.endsWith("/")) "" else "/") + """quantity/inc/$code<[^/]+>""", """controllers.QuantityController.inc(code:String)"""),
    ("""PUT""", prefix + (if(prefix.endsWith("/")) "" else "/") + """quantity/dec/$code<[^/]+>""", """controllers.QuantityController.dec(code:String)"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """quantity/$code<[^/]+>""", """controllers.QuantityController.read(code:String)"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """swagger/""", """controllers.Assets.at(path:String = "/public/swagger/json", file:String = "main.json")"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """swagger/$file<.+>""", """controllers.Assets.at(path:String = "/public/swagger/json", file:String)"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """docs/""", """controllers.Assets.at(path:String = "/public/swagger/", file:String = "index.html")"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """docs/$file<.+>""", """controllers.Assets.at(path:String = "/public/swagger/", file:String)"""),
    ("""GET""", prefix + (if(prefix.endsWith("/")) "" else "/") + """assets/$file<.+>""", """controllers.Assets.versioned(path:String = "/public", file:Asset)"""),
    Nil
  ).foldLeft(List.empty[(String,String,String)]) { (s,e) => e.asInstanceOf[Any] match {
    case r @ (_,_,_) => s :+ r.asInstanceOf[(String,String,String)]
    case l => s ++ l.asInstanceOf[List[(String,String,String)]]
  }}


  // @LINE:7
  private[this] lazy val controllers_Application_index0_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix)))
  )
  private[this] lazy val controllers_Application_index0_invoker = createInvoker(
    controllers.Application.index,
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.Application",
      "index",
      Nil,
      "GET",
      """""",
      this.prefix + """"""
    )
  )

  // @LINE:8
  private[this] lazy val controllers_BoxesEndpoint_create1_route: Route.ParamsExtractor = Route("POST",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("box")))
  )
  private[this] lazy val controllers_BoxesEndpoint_create1_invoker = createInvoker(
    controllers.BoxesEndpoint.create,
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.BoxesEndpoint",
      "create",
      Nil,
      "POST",
      """""",
      this.prefix + """box"""
    )
  )

  // @LINE:10
  private[this] lazy val controllers_DistributionCentreController_search2_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("dc")))
  )
  private[this] lazy val controllers_DistributionCentreController_search2_invoker = createInvoker(
    controllers.DistributionCentreController.search,
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.DistributionCentreController",
      "search",
      Nil,
      "GET",
      """""",
      this.prefix + """dc"""
    )
  )

  // @LINE:11
  private[this] lazy val controllers_DistributionCentreController_create3_route: Route.ParamsExtractor = Route("POST",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("dc")))
  )
  private[this] lazy val controllers_DistributionCentreController_create3_invoker = createInvoker(
    controllers.DistributionCentreController.create,
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.DistributionCentreController",
      "create",
      Nil,
      "POST",
      """""",
      this.prefix + """dc"""
    )
  )

  // @LINE:12
  private[this] lazy val controllers_DistributionCentreController_read4_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("dc/"), DynamicPart("code", """[^/]+""",true)))
  )
  private[this] lazy val controllers_DistributionCentreController_read4_invoker = createInvoker(
    controllers.DistributionCentreController.read(fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.DistributionCentreController",
      "read",
      Seq(classOf[String]),
      "GET",
      """""",
      this.prefix + """dc/$code<[^/]+>"""
    )
  )

  // @LINE:13
  private[this] lazy val controllers_DistributionCentreController_update5_route: Route.ParamsExtractor = Route("PUT",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("dc/"), DynamicPart("code", """[^/]+""",true)))
  )
  private[this] lazy val controllers_DistributionCentreController_update5_invoker = createInvoker(
    controllers.DistributionCentreController.update(fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.DistributionCentreController",
      "update",
      Seq(classOf[String]),
      "PUT",
      """""",
      this.prefix + """dc/$code<[^/]+>"""
    )
  )

  // @LINE:14
  private[this] lazy val controllers_DistributionCentreController_delete6_route: Route.ParamsExtractor = Route("DELETE",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("dc/"), DynamicPart("code", """[^/]+""",true)))
  )
  private[this] lazy val controllers_DistributionCentreController_delete6_invoker = createInvoker(
    controllers.DistributionCentreController.delete(fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.DistributionCentreController",
      "delete",
      Seq(classOf[String]),
      "DELETE",
      """""",
      this.prefix + """dc/$code<[^/]+>"""
    )
  )

  // @LINE:16
  private[this] lazy val controllers_QuantityController_inc7_route: Route.ParamsExtractor = Route("PUT",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("quantity/inc/"), DynamicPart("code", """[^/]+""",true)))
  )
  private[this] lazy val controllers_QuantityController_inc7_invoker = createInvoker(
    controllers.QuantityController.inc(fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.QuantityController",
      "inc",
      Seq(classOf[String]),
      "PUT",
      """""",
      this.prefix + """quantity/inc/$code<[^/]+>"""
    )
  )

  // @LINE:17
  private[this] lazy val controllers_QuantityController_dec8_route: Route.ParamsExtractor = Route("PUT",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("quantity/dec/"), DynamicPart("code", """[^/]+""",true)))
  )
  private[this] lazy val controllers_QuantityController_dec8_invoker = createInvoker(
    controllers.QuantityController.dec(fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.QuantityController",
      "dec",
      Seq(classOf[String]),
      "PUT",
      """""",
      this.prefix + """quantity/dec/$code<[^/]+>"""
    )
  )

  // @LINE:18
  private[this] lazy val controllers_QuantityController_read9_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("quantity/"), DynamicPart("code", """[^/]+""",true)))
  )
  private[this] lazy val controllers_QuantityController_read9_invoker = createInvoker(
    controllers.QuantityController.read(fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.QuantityController",
      "read",
      Seq(classOf[String]),
      "GET",
      """""",
      this.prefix + """quantity/$code<[^/]+>"""
    )
  )

  // @LINE:21
  private[this] lazy val controllers_Assets_at10_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("swagger/")))
  )
  private[this] lazy val controllers_Assets_at10_invoker = createInvoker(
    controllers.Assets.at(fakeValue[String], fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.Assets",
      "at",
      Seq(classOf[String], classOf[String]),
      "GET",
      """ Routing for Swagger""",
      this.prefix + """swagger/"""
    )
  )

  // @LINE:22
  private[this] lazy val controllers_Assets_at11_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("swagger/"), DynamicPart("file", """.+""",false)))
  )
  private[this] lazy val controllers_Assets_at11_invoker = createInvoker(
    controllers.Assets.at(fakeValue[String], fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.Assets",
      "at",
      Seq(classOf[String], classOf[String]),
      "GET",
      """""",
      this.prefix + """swagger/$file<.+>"""
    )
  )

  // @LINE:23
  private[this] lazy val controllers_Assets_at12_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("docs/")))
  )
  private[this] lazy val controllers_Assets_at12_invoker = createInvoker(
    controllers.Assets.at(fakeValue[String], fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.Assets",
      "at",
      Seq(classOf[String], classOf[String]),
      "GET",
      """""",
      this.prefix + """docs/"""
    )
  )

  // @LINE:24
  private[this] lazy val controllers_Assets_at13_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("docs/"), DynamicPart("file", """.+""",false)))
  )
  private[this] lazy val controllers_Assets_at13_invoker = createInvoker(
    controllers.Assets.at(fakeValue[String], fakeValue[String]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.Assets",
      "at",
      Seq(classOf[String], classOf[String]),
      "GET",
      """""",
      this.prefix + """docs/$file<.+>"""
    )
  )

  // @LINE:27
  private[this] lazy val controllers_Assets_versioned14_route: Route.ParamsExtractor = Route("GET",
    PathPattern(List(StaticPart(this.prefix), StaticPart(this.defaultPrefix), StaticPart("assets/"), DynamicPart("file", """.+""",false)))
  )
  private[this] lazy val controllers_Assets_versioned14_invoker = createInvoker(
    controllers.Assets.versioned(fakeValue[String], fakeValue[Asset]),
    HandlerDef(this.getClass.getClassLoader,
      "router",
      "controllers.Assets",
      "versioned",
      Seq(classOf[String], classOf[Asset]),
      "GET",
      """ Map static resources from the /public folder to the /assets URL path""",
      this.prefix + """assets/$file<.+>"""
    )
  )


  def routes: PartialFunction[RequestHeader, Handler] = {
  
    // @LINE:7
    case controllers_Application_index0_route(params) =>
      call { 
        controllers_Application_index0_invoker.call(controllers.Application.index)
      }
  
    // @LINE:8
    case controllers_BoxesEndpoint_create1_route(params) =>
      call { 
        controllers_BoxesEndpoint_create1_invoker.call(controllers.BoxesEndpoint.create)
      }
  
    // @LINE:10
    case controllers_DistributionCentreController_search2_route(params) =>
      call { 
        controllers_DistributionCentreController_search2_invoker.call(controllers.DistributionCentreController.search)
      }
  
    // @LINE:11
    case controllers_DistributionCentreController_create3_route(params) =>
      call { 
        controllers_DistributionCentreController_create3_invoker.call(controllers.DistributionCentreController.create)
      }
  
    // @LINE:12
    case controllers_DistributionCentreController_read4_route(params) =>
      call(params.fromPath[String]("code", None)) { (code) =>
        controllers_DistributionCentreController_read4_invoker.call(controllers.DistributionCentreController.read(code))
      }
  
    // @LINE:13
    case controllers_DistributionCentreController_update5_route(params) =>
      call(params.fromPath[String]("code", None)) { (code) =>
        controllers_DistributionCentreController_update5_invoker.call(controllers.DistributionCentreController.update(code))
      }
  
    // @LINE:14
    case controllers_DistributionCentreController_delete6_route(params) =>
      call(params.fromPath[String]("code", None)) { (code) =>
        controllers_DistributionCentreController_delete6_invoker.call(controllers.DistributionCentreController.delete(code))
      }
  
    // @LINE:16
    case controllers_QuantityController_inc7_route(params) =>
      call(params.fromPath[String]("code", None)) { (code) =>
        controllers_QuantityController_inc7_invoker.call(controllers.QuantityController.inc(code))
      }
  
    // @LINE:17
    case controllers_QuantityController_dec8_route(params) =>
      call(params.fromPath[String]("code", None)) { (code) =>
        controllers_QuantityController_dec8_invoker.call(controllers.QuantityController.dec(code))
      }
  
    // @LINE:18
    case controllers_QuantityController_read9_route(params) =>
      call(params.fromPath[String]("code", None)) { (code) =>
        controllers_QuantityController_read9_invoker.call(controllers.QuantityController.read(code))
      }
  
    // @LINE:21
    case controllers_Assets_at10_route(params) =>
      call(Param[String]("path", Right("/public/swagger/json")), Param[String]("file", Right("main.json"))) { (path, file) =>
        controllers_Assets_at10_invoker.call(controllers.Assets.at(path, file))
      }
  
    // @LINE:22
    case controllers_Assets_at11_route(params) =>
      call(Param[String]("path", Right("/public/swagger/json")), params.fromPath[String]("file", None)) { (path, file) =>
        controllers_Assets_at11_invoker.call(controllers.Assets.at(path, file))
      }
  
    // @LINE:23
    case controllers_Assets_at12_route(params) =>
      call(Param[String]("path", Right("/public/swagger/")), Param[String]("file", Right("index.html"))) { (path, file) =>
        controllers_Assets_at12_invoker.call(controllers.Assets.at(path, file))
      }
  
    // @LINE:24
    case controllers_Assets_at13_route(params) =>
      call(Param[String]("path", Right("/public/swagger/")), params.fromPath[String]("file", None)) { (path, file) =>
        controllers_Assets_at13_invoker.call(controllers.Assets.at(path, file))
      }
  
    // @LINE:27
    case controllers_Assets_versioned14_route(params) =>
      call(Param[String]("path", Right("/public")), params.fromPath[Asset]("file", None)) { (path, file) =>
        controllers_Assets_versioned14_invoker.call(controllers.Assets.versioned(path, file))
      }
  }
}