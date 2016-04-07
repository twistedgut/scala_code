package helpers

import domain.{SmcCurrency, ShippingOptionSearchResult}
import repository.TestDatabase
import test._
import scala.concurrent.ExecutionContext.Implicits.global

import scala.concurrent.Future
import scala.math.BigDecimal.RoundingMode


trait TestShippingOption {
  this: TestDatabase =>

  def createTestShippingOption(testCurrency: SmcCurrency = TestCurrency()) : Future[ShippingOptionSearchResult] = {
    val testCountry = TestCountry()
    val testDivision = TestDivision(testCountry)
    val testPostCodeGroup = TestPostCodeGroup()
    val testShippingOption = TestShippingOption()
    val testDC = TestDC()
    val testAvailability = TestAvailability()
    val testBusiness = TestBusiness()

    for {
      soId <- database.createDBShippingOption(testShippingOption)
      cId <- database.createDbCountry(testCountry)
      dId <- database.createDbDivision(cId, testDivision)
      pcgId <- database.createDbPostCodeGroup(testPostCodeGroup)
      cyId <- database.createDbCurrency(testCurrency)
      bId <- database.createDbBusiness(testBusiness)
      aId <- database.createDbAvailability(
        testAvailability,
        Some(cId),
        Some(dId),
        Some(pcgId),
        cyId,
        soId,
        testDC.code,
        bId
      )
    } yield ShippingOptionSearchResult(
      aId,
      testShippingOption.name,
      Some(testCountry.name),
      Some(testDivision.name),
      Some(testPostCodeGroup.name),
      testAvailability.dcCode,
      testAvailability.price.setScale(2, RoundingMode.HALF_UP),
      testCurrency.code,
      cyId,
      testAvailability.doesPriceIncludeTax,
      testAvailability.isEnabled,
      Some(testBusiness.name),
      testAvailability.isCustomerFacing,
      testAvailability.signatureRequiredStatusId
    )
  }
}