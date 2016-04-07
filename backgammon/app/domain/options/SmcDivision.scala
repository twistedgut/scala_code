package domain

import play.api.libs.json.Json

case class SmcDivision(name: String, code: String, countryCode: String)

object SmcDivision {
  implicit val format = Json.format[SmcDivision]
}