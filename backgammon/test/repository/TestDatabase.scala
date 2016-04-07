package repository

import database.Tables
import domain._
import domain.options.SmcStage
import test.TestRestriction.SmcRestriction
import scala.concurrent.ExecutionContext.Implicits.global
import test._

import scala.concurrent.Future

trait TestDatabase extends PostgresDatabase
                    with SlickHealth
                    with SlickOptions
                    with SlickShippingOption
                    with SlickDeliveryRestrictions
                    with Tables {

  object database {
    import profile.api._

    def createDbCurrency(currency: SmcCurrency = TestCurrency()): Future[Int] =
      db.run((Currency.map(c => (c.name, c.code)) returning Currency.map(_.id)) += ((currency.name, currency.code)))

    def createDbDivision(countryId : Int, division  : SmcDivision): Future[Int] =
      db.run((Division.map(d => (d.name, d.code, d.countryId)) returning Division.map(_.id)) += ((division.name, division.code, countryId)))

    def createDbBusiness(business: SmcBusiness): Future[Int] =
      db.run((Business.map(b => (b.name, b.code)) returning Business.map(_.id)) += ((business.name, business.code)))

    def createDbPostCodeGroup(postcodeGroup: SmcPostCodeGroup = TestPostCodeGroup()): Future[Int] =
      db.run((PostCodeGroup.map(pcg => (pcg.name, pcg.code)) returning PostCodeGroup.map(_.id)) += ((postcodeGroup.name, postcodeGroup.code)))

    def createDbCountry(country: SmcCountry = TestCountry()): Future[Int] =
      db.run((Country.map(c => (c.name, c.code)) returning Country.map(_.id)) += ((country.name, country.code)))

    // THIS CAN BE REFACTORED OUT WHEN A CREATE SHIPPING OPTION ENDPOINT IS CREATED (USE THAT INSTEAD)
    def createDBShippingOption(shOption: SmcShippingOption = TestShippingOption()): Future[Int] =
      db.run((ShippingOption.map(o => (o.name, o.code, o.isLimitedAvailability)) returning ShippingOption.map(_.id)) += ((shOption.name, shOption.code, shOption.isLimitedAvailability)))

    def genStageRank: Future[Int] =
      db.run(Stage.sortBy(_.ranking.desc).map(_.ranking).result.headOption).map(s => s.getOrElse(0))

    def createDBStage(smcStage: SmcStage): Future[Int] =
      db.run((Stage.map(s => (s.name, s.code, s.ranking)) returning Stage.map(_.id)) += (smcStage.name, smcStage.code, smcStage.ranking))

    def createDBRestriction(smcRes: SmcRestriction): Future[Int] = {
      db.run((Restriction.map(r => (r.restrictedDate, r.shippingAvailabilityId, r.stageId, r.isRestricted)) returning Restriction.map(_.id)) += (smcRes.restrictedDate, smcRes.availabilityId, smcRes.stageId, smcRes.isRestricted))
    }

    def readAvailability(avId: Int) =
      db.run(Availability.filter(_.id === avId).result.headOption)

    def readBusiness(busId: Int): Future[String] =
      db.run(Business.filter(_.id === busId).map(_.code).result.head)

    def createDbAvailability( // Todo : Can be refactored to create them if you don't pass them in :
                              availability    : SmcAvailability,
                              countryId       : Option[Int],
                              divisionId      : Option[Int],
                              postCodeGroupId : Option[Int],
                              currencyId      : Int,
                              optionId        : Int,
                              dcCode          : String,
                              businessId      : Int
                              ) =
      db.run((Availability.map(a => (
        a.optionId,
        a.countryId,
        a.businessId,
        a.isEnabled,
        a.isCustomerFacing,
        a.price,
        a.currencyId,
        a.doesPriceIncludeTax,
        a.legacySku,
        a.createdAt,
        a.signatureRequiredStatusId,
        a.customerSelectableCutoffTime,
        a.customerSelectableOffset,
        a.divisionId,
        a.postCodeGroupId,
        a.packagingGroupId,
        a.dc
        ))
        returning Availability.map(_.id)) +=

        ((optionId,
          countryId,
          businessId,
          availability.isEnabled,
          availability.isCustomerFacing,
          availability.price,
          currencyId,
          availability.doesPriceIncludeTax,
          availability.legacySku,
          availability.createdAt,
          availability.signatureRequiredStatusId,
          availability.customerSelectableCutoffTime,
          availability.customerSelectableOffset,
          divisionId,
          postCodeGroupId,
          availability.packagingGroupId,
          dcCode
          )))

  }
}
