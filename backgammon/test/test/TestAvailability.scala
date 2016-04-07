package test

import java.sql.Timestamp
import java.time.LocalDateTime

import domain.SmcAvailability

object TestAvailability {

  val nameCodeGenerator = Counter { suffix =>
    (
      if (1 == suffix % 2) true else false,
      s"LegacySku-$suffix",
      if (1 == suffix % 2) 1 else 3
      )
  }

  //Does not include ID's provided by other Test Data!

  // Todo Remove business, packagingGroupId and signatureRequiredStatusId and use real ids when they become available in the endpoints
  // (not worth it for now just for the tests)

  val (genBoolean, genLegacySku, genSignatureRequiredId) = nameCodeGenerator.next()


  def apply(
             businessId                   : Int                   = 1,
             isEnabled                    : Boolean               = genBoolean,
             isCustomerFacing             : Boolean               = genBoolean,
             price                        : scala.math.BigDecimal = 1.00,
             doesPriceIncludeTax          : Boolean               = genBoolean,
             legacySku                    : String                = genLegacySku,
             createdAt                    : java.sql.Timestamp    = Timestamp.valueOf(LocalDateTime.now),
             signatureRequiredStatusId    : Int                   = genSignatureRequiredId,
             customerSelectableCutoffTime : Option[java.sql.Time] = None,
             customerSelectableOffset     : Option[Int]           = None,
             packagingGroupId             : Option[Int]           = None,
             dcCode                       : String                = "DC1"
          ) = SmcAvailability(
                businessId,
                isEnabled,
                isCustomerFacing,
                price,
                doesPriceIncludeTax,
                legacySku,
                createdAt,
                signatureRequiredStatusId,
                customerSelectableCutoffTime,
                customerSelectableOffset,
                packagingGroupId,
                dcCode
              )
}
