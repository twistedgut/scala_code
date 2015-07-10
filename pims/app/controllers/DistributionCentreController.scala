package controllers

import domain._
import play.api._
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import play.api.libs.json._
import play.api.mvc._
import repository._
import scala.util._
import scala.concurrent._

trait DistributionCentreController extends Controller {
  this: DistributionCentres with Formats with ControllerHelperMethods =>

  def search = Action.async { request =>
    distributionCentres.search().map(dcs => Ok(Json.toJson(dcs)))
  }

  def create = Action.async(parse.json) { request =>
    withRequestBodyAs[DistributionCentre](request) { dc =>
      distributionCentres.create(dc).map(_ => Ok(""))
    }
  }

  def read(code: String) = Action.async { request =>
    distributionCentres.read(code) flatMap {
      case Some(dc) => Future.successful(Ok(Json.toJson(dc)))
      case None     => Future.failed(NotFoundException("DC", code))
    }
  }

  def update(code: String) = Action.async(parse.json) { request =>
    withRequestBodyAs[DistributionCentre](request) { dc =>
      distributionCentres.update(code, dc).map(_ => Ok(""))
    }
  }

  def delete(code: String) = Action.async { request =>
    distributionCentres.delete(code).map(_ => Ok(""))
  }

}

object DistributionCentreController extends DistributionCentreController
  with Slick
  with Formats
  with ControllerHelperMethods
