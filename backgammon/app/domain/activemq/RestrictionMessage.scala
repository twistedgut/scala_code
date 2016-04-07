package domain.activemq

import play.api.libs.json.Json

case class RestrictionMessage(
  channel          :String,
  restricted_dates :Seq[AmqDeliveryRestriction],
  window           :RestrictionWindow
)

object RestrictionMessage {
  implicit val jsonFormat = Json.format[RestrictionMessage]
}
