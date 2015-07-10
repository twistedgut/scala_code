import play.api._
import play.api.mvc._
import play.api.libs.json._
import repository.StandardError
import scala.concurrent.Future

object Global extends GlobalSettings with Results {
  override def onError(request: RequestHeader, exn: Throwable) = {
    exn match {
      case exn: StandardError =>
        Future.successful(exn.toResult)

      case exn =>
        Logger.error("Error 500: " + exn.getMessage, exn)
        Future.successful(InternalServerError(Json.obj(
          "error" -> exn.getMessage
        )))
    }
  }
}