package controllers

import play.api._
import play.api.mvc._
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import scala.util.Success
import repository._
import domain.Box
import domain.Formats
import scala.util._

trait BoxesEndpoint extends Controller {
  this: Boxes with Formats =>

  def create() = Action.async(parse.json) { request =>
    val box = request.body.as[Box]
    boxes.store(box) map ( _ => Ok("") )
  }

}

object BoxesEndpoint extends BoxesEndpoint
                                with MySqlDatabase
                                with SlickBoxes
                                with SlickTables
                                with Formats
