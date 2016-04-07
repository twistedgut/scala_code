package domain.activemq

import play.api.libs.json.Json

case class AmqChannelRestriction (
  deliveryRestriction: AmqDeliveryRestriction,
  business_code:       String
)

object AmqChannelRestriction {
  implicit val jsonFormat = Json.format[AmqChannelRestriction]
}
