package domain

import play.api.libs.json.Json

case class SmcBusiness(name: String, code: String)

object SmcBusiness {
  implicit val format = Json.format[SmcBusiness]
}