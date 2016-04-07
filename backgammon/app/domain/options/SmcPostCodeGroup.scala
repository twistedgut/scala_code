package domain

import play.api.libs.json.Json

case class SmcPostCodeGroup(name: String, code: String)

object SmcPostCodeGroup {
  implicit val format = Json.format[SmcPostCodeGroup]
}