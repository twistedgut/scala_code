import play.api.http.Writeable
import play.api.libs.json.{Reads, JsValue, Json, Writes}
import play.api.mvc.{AnyContent, Request}
import scala.language.implicitConversions

package object domain {

  def buildResponse[A,B](responseBody :A = None)(implicit request :Request[B], jsonWrites: Writes[A]) = APIResponse(
      uri = request.path,
      success = true,
      error_msg = "",
      responseBody = Some(Json.toJson(responseBody))
    )

  implicit def fromJsonToResponse[A](implicit jsonWrites: Writes[A], writable: Writeable[JsValue]): play.api.http.Writeable[A] =
    writable.map[A](in => Json.toJson(in))

  implicit class RequestExtensions[B](val request: Request[AnyContent]) extends AnyVal {
    def bodyAs[A](implicit reads: Reads[A]) : Option[A] = {
      request.body.asJson.flatMap(json => Json.fromJson(json).asOpt)
    }
  }
}
