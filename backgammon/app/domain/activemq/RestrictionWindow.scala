package domain.activemq

import play.api.libs.json.Json

case class RestrictionWindow (
  begin_date :String,
  end_date   :String
)

object RestrictionWindow {
  implicit val jsonFormat = Json.format[RestrictionWindow]
}
