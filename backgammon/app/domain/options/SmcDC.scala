package domain

import play.api.libs.json.Json

case class SmcDC(code: String, name: String)

object SmcDC {
  implicit val format = Json.format[SmcDC]
}