package controllers

import play.api._
import play.api.mvc._
import play.api.libs.json.Json.toJson

import domain._

object Application extends Controller with Formats {

  def index = Action {
    Ok(toJson(Index))
  }

}
