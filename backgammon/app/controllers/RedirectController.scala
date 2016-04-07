package controllers

import play.api.mvc.{Controller, Action}

trait RedirectController extends Controller {
  def index() = Action { Redirect("/docs/")}
  def redirect(returnURL :String) = Action { Redirect(returnURL) }
}

class RedirectControllerImpl extends RedirectController
