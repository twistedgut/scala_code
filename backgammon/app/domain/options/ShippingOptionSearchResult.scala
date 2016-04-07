package domain

import play.api.libs.json._

//Based on what we want to pass to the UI

case class ShippingOptionSearchResult(
                           avId                 : Int,
                           optionName           : String,
                           countryName          : Option[String],
                           divisionName         : Option[String],
                           postcodeGroupName    : Option[String],
                           dcCode               : String,
                           price                : BigDecimal,
                           currencyName         : String,
                           currencyId           : Int,
                           isTaxInc             : Boolean,
                           isLive               : Boolean,
                           business             : Option[String],
                           isCustomerFacing     : Boolean,
                           isSignatureRequired  : Int
                           )

object ShippingOptionSearchResult {
  implicit val format = Json.format[ShippingOptionSearchResult]
}