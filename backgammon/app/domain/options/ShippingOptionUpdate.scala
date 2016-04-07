package domain.options

import play.api.libs.json._


case class ShippingOptionUpdate(
                                 isEnabled                : Boolean,
                                 isCustomerFacing         : Boolean,
                                 price                    : BigDecimal,
                                 currencyCode             : String,
                                 signatureRequiredStatusId: Int,
                                 isTaxInc                 : Boolean )

object ShippingOptionUpdate {
  implicit val format = Json.format[ShippingOptionUpdate]
}