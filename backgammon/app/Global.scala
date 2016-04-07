import play.api._
import play.api.libs.json._
import play.api.mvc._
import repository.StandardError
import scala.concurrent.Future
import domain.InvalidEntity

object Global extends GlobalSettings with Results {
  override def onError(request: RequestHeader, exn: Throwable) = {
    exn match {
      case exn: StandardError =>
        Future.successful(exn.toResult)

      case invalid: InvalidEntity => Future.successful(BadRequest(invalid.getMessage))

      case exn =>
        Logger.error("Error 500: " + exn.getMessage, exn)
        Future.successful(InternalServerError(Json.obj(
          "error" -> exn.getMessage
        )))
    }
  }
}