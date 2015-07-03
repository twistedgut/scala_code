package controllers

import play.api._
import play.api.libs.json.JsValue
import play.api.mvc._
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import scala.util.Success
import repository._
import domain.{Box, Quantity, Formats}
import scala.util._


trait QuantityEndpoint extends Controller {
  //this: Quantity with Formats =>
  this: Quantities =>

  def update(boxCode: String) = Action.async(parse.json) { request =>
    val json = request.body
    val updateQuantity = (json \ "quantity").as[Int]
    val quantity = Quantity(boxCode, updateQuantity)
    quantityUpdate.increment(quantity) map ( _ => Ok("") )
  }

}

object QuantityEndpoint extends QuantityEndpoint with SlickQuantity with SlickTables with Formats

