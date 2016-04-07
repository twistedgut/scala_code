package repository

import domain.ShippingOptionSearchResult
import domain.options.ShippingOptionUpdate
import helpers.TestShippingOption
import org.specs2.specification.Scope
import play.api.test.PlaySpecification
import test.{TestCurrency, TestShippingOption}

class SlickShippingOptionSpec extends PlaySpecification {

  class TestSlickShippingOption extends SlickOptions
          with TestDatabase
          with Scope
          with TestShippingOption


  "update method" should {
    "Successfully update a shipping option" in new TestSlickShippingOption  {
      val currency = TestCurrency()
      val originalOption = await(createTestShippingOption(currency))
      val optionUpdate = ShippingOptionUpdate(
        false,
        true,
        BigDecimal(34.00),
        currency.code,
        1,
        true
      )

      val result = await(shippingOption.updateOption(originalOption.avId, optionUpdate))
      result mustEqual 1

    }
    "Not change the option if the update fails and throw apropriate error" in new TestSlickShippingOption {
      val currency = TestCurrency()
      val originalOption: ShippingOptionSearchResult = await(createTestShippingOption(currency))
      val optionUpdate = ShippingOptionUpdate(
        false,
        true,
        BigDecimal(34.00),
        currency.code,
        1,
        true
      )

      await(shippingOption.updateOption(originalOption.avId + 50000, optionUpdate)) must throwA[FailedUpdateException]

      val postUpdateOption: Option[AvailabilityRow] =  await(database.readAvailability(originalOption.avId))

      postUpdateOption match {
        case Some(option) =>
          option.id mustEqual originalOption.avId
          option.isEnabled mustEqual originalOption.isLive
          option.isCustomerFacing mustEqual originalOption.isCustomerFacing
          option.signatureRequiredStatusId mustEqual originalOption.isSignatureRequired

        case None => false

      }
    }
    "Not change the option if the currency doesn't exist and throw apropriate error" in new TestSlickShippingOption {
      val originalOption: ShippingOptionSearchResult = await(createTestShippingOption())

      val optionUpdate = ShippingOptionUpdate(
        false,
        true,
        BigDecimal(34.00),
        "UNKNOWN",
        1,
        true
      )

      await(shippingOption.updateOption(originalOption.avId, optionUpdate)) must throwA[FailedUpdateException]

      val postUpdateOption: Option[AvailabilityRow] =  await(database.readAvailability(originalOption.avId))

      postUpdateOption match {
        case Some(option) =>
          option.id mustEqual originalOption.avId
          option.isEnabled mustEqual originalOption.isLive
          option.isCustomerFacing mustEqual originalOption.isCustomerFacing
          option.signatureRequiredStatusId mustEqual originalOption.isSignatureRequired

        case None => false

      }
    }
  }
}