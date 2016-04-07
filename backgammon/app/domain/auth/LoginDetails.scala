package domain.auth

import play.api.libs.json.Json

case class LoginDetails(username :String, password :String)
object LoginDetails {
  implicit val jsonFormat = Json.format[LoginDetails]
}

