
// @GENERATOR:play-routes-compiler
// @SOURCE:/vagrant/conf/routes
// @DATE:Fri Jul 10 16:02:14 UTC 2015


package router {
  object RoutesPrefix {
    private var _prefix: String = "/"
    def setPrefix(p: String): Unit = {
      _prefix = p
    }
    def prefix: String = _prefix
    val byNamePrefix: Function0[String] = { () => prefix }
  }
}
