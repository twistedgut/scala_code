package domain.activemq

import play.api.libs.json.Json

case class AmqDeliveryRestriction(
  date                :String,
  restriction_type    :String,
  shipping_charge_sku :String
)

object AmqDeliveryRestriction {
  implicit val jsonFormat = Json.format[AmqDeliveryRestriction]
}
