package domain.auth

import play.api.libs.json.Json

case class LoginInfo(username: String, is_logged_in :Boolean, is_admin :Boolean)
object LoginInfo {
  implicit val jsonFormat = Json.format[LoginInfo]
}
