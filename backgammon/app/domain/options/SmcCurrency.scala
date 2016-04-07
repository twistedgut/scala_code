package domain

import play.api.libs.json.Json

case class SmcCurrency(name: String, code: String)

object SmcCurrency {
  implicit val format = Json.format[SmcCurrency]
}