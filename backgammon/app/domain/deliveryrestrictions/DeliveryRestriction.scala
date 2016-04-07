package domain.deliveryrestrictions

import play.api.libs.json.Json

case class DeliveryRestriction(
  restrictedDate : String,
  availabilityId : Int,
  stage          : String
)

object DeliveryRestriction {
  implicit val jsonFormat = Json.format[DeliveryRestriction]
}

case class DeliveryRestrictionUpdate(
  operation       : String,
  restriction     : DeliveryRestriction
)

object DeliveryRestrictionUpdate {
  implicit val jsonFormat = Json.format[DeliveryRestrictionUpdate]
}

case class DeliveryRestrictionResend(
  fromDate: String,
  toDate: String,
  dcCode: String
)

object DeliveryRestrictionResend {
  implicit val jsonFormat = Json.format[DeliveryRestrictionResend]
}