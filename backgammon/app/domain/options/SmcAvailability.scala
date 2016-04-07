package domain

import java.sql.Timestamp

case class SmcAvailability(
                              businessId                  : Int,
                              isEnabled                   : Boolean,
                              isCustomerFacing            : Boolean,
                              price                       : scala.math.BigDecimal,
                              doesPriceIncludeTax         : Boolean,
                              legacySku                   : String,
                              createdAt                   : Timestamp,
                              signatureRequiredStatusId   : Int,
                              customerSelectableCutoffTime: Option[java.sql.Time] = None,
                              customerSelectableOffset    : Option[Int]           = None,
                              packagingGroupId            : Option[Int]           = None,
                              dcCode                      : String
                              )
