package helpers

import domain.ShippingOptionSearchResult
import domain.deliveryrestrictions.{DeliveryRestrictionUpdate, DeliveryRestriction}
import domain.options.{ShippingOptionUpdate, ShippingOptionUpdate$}
import test.Counter


trait TestResponses {

  def fakeShippingOptionUpdate() = {
    Counter { suffix =>
      ShippingOptionUpdate(
        1 == suffix % 2,
        1 == suffix % 2,
        BigDecimal(suffix),
        s"Currency code $suffix",
        suffix.toInt,
        1 == suffix % 2
      )
    }
  }

  def fakeShippingOptionSearchResult() =  {
    Counter { suffix =>
      ShippingOptionSearchResult(
        suffix.toInt,
        s"Option Name $suffix",
        Some(s"Country Name $suffix"),
        Some(s"Division Name $suffix"),
        Some(s"PostCodeGroup Name $suffix"),
        s"DC $suffix",
        BigDecimal(suffix),
        "Currency Name $suffix",
        suffix.toInt,
        1 == suffix % 2,
        1 == suffix % 2,
        Some(s"Business Name $suffix"),
        1 == suffix % 2,
        suffix.toInt
      )
    }
  }

  def fakeShippingRestrictionsSearchResult() = {
    Counter { suffix =>
      DeliveryRestriction(
        "2016-01-15",
        1,
        "myStage"
      )
    }
  }

  def fakeRestrictionUpdate() = {
    Counter { suffix =>
      DeliveryRestrictionUpdate(
        suffix.toString,
        fakeShippingRestrictionsSearchResult().next
      )
    }
  }
}