package domain

import play.api.libs.json.Json

case class SmcCountry(name: String, code: String)

object SmcCountry {
  implicit val format = Json.format[SmcCountry]
}