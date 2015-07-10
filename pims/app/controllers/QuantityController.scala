package controllers

import domain._
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import play.api.libs.json._
import play.api.mvc._
import repository._

trait QuantityController extends Controller {
  this: Quantities with Formats with ControllerHelperMethods =>

  def read(code: String) = Action.async { request =>
    quantities.read(code) map (quantity => Ok(Json.toJson(quantity)))
  }

  def inc(code: String) = Action.async(parse.json) { request =>
    withRequestBodyAs[UpdateQuantity](request) { uq =>
      quantities.inc(code, uq).map(_ => Ok(""))
    }
  }

  def dec(code: String) = Action.async(parse.json) { request =>
    withRequestBodyAs[UpdateQuantity](request) { uq =>
      quantities.dec(code, uq).map(_ => Ok(""))
    }
  }
}

object QuantityController extends QuantityController
  with Slick
  with Formats
  with ControllerHelperMethods
