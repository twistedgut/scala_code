package controllers

import play.api.mvc._
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import repository._
import domain.Box

trait BoxesEndpoint extends Controller {
  this: Boxes with Formats =>

  def create() = Action.async(parse.json) { request =>
    val box = request.body.as[Box]
    boxes.store(box) map ( _ => Ok("") )
  }

}

object BoxesEndpoint extends BoxesEndpoint
                                with Slick
                                with Formats
