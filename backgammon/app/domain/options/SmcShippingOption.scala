package domain

import play.api.libs.json.Json

case class SmcShippingOption(
    name:                   String,
    code:                   String,
    isLimitedAvailability:  Boolean
    )

object SmcShippingOption {
  implicit val format = Json.format[SmcShippingOption]
}
