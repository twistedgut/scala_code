package domain

import play.api.libs.json._

case class NoInput(val x :String)
object NoInput {
  implicit val noInputFormat = Json.format[NoInput]
}

// this wraps _EVERY SINGLE_ response!

// It allows the client to exchange tokens, timestamps, deal with other errors on the back
// of other ajax calls!

case class APIResponse(
    uri :String,
    responseBody :Option[JsValue],
    success :Boolean,
    error_msg :String
)

object APIResponse {
  implicit val apiResponseFormat = Json.format[APIResponse]
}