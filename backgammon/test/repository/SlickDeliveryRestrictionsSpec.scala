package repository

import domain.activemq.{AmqDeliveryRestriction, AmqChannelRestriction, RestrictionWindow}
import domain.deliveryrestrictions.{DeliveryRestriction, DeliveryRestrictionUpdate}
import helpers.{TestRestriction, TestShippingOption}
import org.specs2.specification.Scope
import play.api.test.PlaySpecification
import test.TestStage

class SlickDeliveryRestrictionsSpec extends PlaySpecification {

  class TestSlickDeliveryRestrictions extends TestDatabase with Scope

  "Get Delivery restrictions" should {
    "Return an empty list for an option with no delivery restrictions" in new TestSlickDeliveryRestrictions with TestShippingOption {
      val option = await(createTestShippingOption())

      val result = await(deliveryRestrictions.get(List(option.avId), "2014-10-23", "2017-10-23", List("Transit")))

      result mustEqual List.empty
    }

    "Return applicable restriction dates" in new TestSlickDeliveryRestrictions with TestRestriction {
      val restrictedDate1 = "2016-01-15"
      val restrictedDate2 = "2016-01-17"
      val option = await(createTestShippingOption())

      // Ensure the ranking is unique
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)

      // Create Restriction and Stage in DB
      val stageID = await(database.createDBStage(stage))
      await(createRestriction(java.sql.Date.valueOf(restrictedDate1), true, stageID, option.avId))
      await(createRestriction(java.sql.Date.valueOf(restrictedDate2), true, stageID, option.avId))

      // Results
      val expectedResults = Seq(DeliveryRestriction(restrictedDate1, option.avId, stage.code), DeliveryRestriction(restrictedDate2, option.avId, stage.code))
      val results = await(deliveryRestrictions.get(List(option.avId), "2015-12-23", "2016-03-24", List(stage.code)))
      results mustEqual expectedResults
    }

    "Not include restrictions for other stages in the results" in new TestSlickDeliveryRestrictions with TestRestriction {
      val restrictedDate = "2016-01-15"
      val option = await(createTestShippingOption())

      // Ensure the ranking is unique
      val ranking = await(database.genStageRank)
      val stage1 = TestStage(ranking + 1)
      val stage2 = TestStage(ranking + 2)

      // Create Restriction and Stage in DB
      val stage1Id = await(database.createDBStage(stage1))
      val stage2Id = await(database.createDBStage(stage2))
      await(createRestriction(java.sql.Date.valueOf(restrictedDate), true, stage1Id, option.avId))
      await(createRestriction(java.sql.Date.valueOf(restrictedDate), true, stage2Id, option.avId))

      val expectedResults = Seq(DeliveryRestriction(restrictedDate, option.avId, stage1.code))
      val results = await(deliveryRestrictions.get(List(option.avId), "2015-12-23", "2016-03-24", List(stage1.code)))
      results mustEqual expectedResults
    }

    "Not incude restrictions which are disabled" in new TestSlickDeliveryRestrictions with TestRestriction {
      val restrictedDate: java.sql.Date = java.sql.Date.valueOf("2016-01-15")
      val option = await(createTestShippingOption())
      // Ensure the ranking is unique
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)

      // Create Restriction and Stage in DB
      val stageId = await(database.createDBStage(stage))
      await(createRestriction(restrictedDate, false, stageId, option.avId))
      val results = await(deliveryRestrictions.get(List(option.avId), "2015-12-23", "2016-03-24", List(stage.code)))
      results mustEqual List.empty
    }

    "Not include restrictions for other options" in new TestSlickDeliveryRestrictions with TestRestriction {
      val restrictedDate: java.sql.Date = java.sql.Date.valueOf("2016-01-15")
      val option1 = await(createTestShippingOption())
      val option2 = await(createTestShippingOption())
      // Ensure the ranking is unique
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)

      // Create Restriction and Stage in DB
      val stageId = await(database.createDBStage(stage))
      await(createRestriction(restrictedDate, true, stageId, option1.avId))
      val results = await(deliveryRestrictions.get(List(option2.avId), "2015-12-23", "2016-03-24", List(stage.code)))
      results mustEqual List.empty
    }
  }
  "Update Delivery Restrictions" should {
    "Successfully insert a sequence of restrictions" in new TestSlickDeliveryRestrictions with TestRestriction {

      // Create Options
      val option = await(createTestShippingOption())
      val option2 = await(createTestShippingOption())

      // Create ranking/ restrictions
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)
      val stageId = await(database.createDBStage(stage))

      // Create restrictions
      val date = "2016-02-15"
      val resUpdate = DeliveryRestrictionUpdate("insert",  DeliveryRestriction(date, option.avId, stage.code))
      val resUpdate2 = DeliveryRestrictionUpdate("insert",  DeliveryRestriction(date, option2.avId, stage.code))
      val updateResult = await(deliveryRestrictions.update(Seq(resUpdate, resUpdate2)))

      // Ensure update is successful
      updateResult mustEqual true

      val result = await(deliveryRestrictions.get(List(option.avId, option2.avId), "2016-02-14", "2016-02-16", List(stage.code)))
      val expectedResult = Seq(DeliveryRestriction(date, option.avId, stage.code), DeliveryRestriction(date, option2.avId, stage.code))

      // Ensure restrictions are updated correctly
      result mustEqual expectedResult
    }
    "Successfully delete a sequence of restrictions" in new TestSlickDeliveryRestrictions with TestRestriction {
      // Create Options
      val initialRestrictedDate = "2016-01-15"
      val option = await(createTestShippingOption())
      val option2 = await(createTestShippingOption())

      // Create ranking/ restrictions
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)
      val stageId = await(database.createDBStage(stage))
      val resId = await(createRestriction(java.sql.Date.valueOf(initialRestrictedDate), true, stageId, option.avId))
      val res2Id = await(createRestriction(java.sql.Date.valueOf(initialRestrictedDate), true, stageId, option2.avId))

      // Delete restrictions
      val dateUpdate: java.sql.Date = java.sql.Date.valueOf("2016-02-15")
      val resUpdate = DeliveryRestrictionUpdate("delete",  DeliveryRestriction(initialRestrictedDate, option.avId, stage.code))
      val resUpdate2 = DeliveryRestrictionUpdate("delete", DeliveryRestriction(initialRestrictedDate, option2.avId, stage.code))

      val res = await(deliveryRestrictions.update(Seq(resUpdate, resUpdate2)))

      res mustEqual true
      val result = await(deliveryRestrictions.get(List(option.avId, option2.avId), "2016-01-14", "2016-02-16", List(stage.code)))

      // Ensure restrictions are updated correctly
      result mustEqual Seq()
    }
    "Successfully delete/insert a sequence of restrictions" in new TestSlickDeliveryRestrictions with TestRestriction {
      // Create Options
      val option = await(createTestShippingOption())
      val option2 = await(createTestShippingOption())

      val date1 = "2016-02-15"
      val date2 = "2016-02-16"

      val javaDate1 = java.sql.Date.valueOf(date1)

      // Create stage
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)
      val stageId = await(database.createDBStage(stage))
      val resId = await(createRestriction(javaDate1, true, stageId, option.avId))

      // Delete/insert restrictions
      val resUpdate = DeliveryRestrictionUpdate("insert",  DeliveryRestriction(date2, option2.avId, stage.code))
      val resUpdate2 = DeliveryRestrictionUpdate("delete",  DeliveryRestriction(date1, option.avId, stage.code))

      val res = await(deliveryRestrictions.update(Seq(resUpdate2, resUpdate)))

      res mustEqual true
      val result = await(deliveryRestrictions.get(List(option.avId, option2.avId), "2016-02-14", "2016-02-17", List(stage.code)))

      // Ensure restrictions are updated correctly
      result mustEqual Seq(DeliveryRestriction(date2, option2.avId, stage.code))
    }

    "Throw correct error when update fails" in new TestSlickDeliveryRestrictions with TestRestriction {
      // Create Options
      val date = "2016-01-15"
      val javaDate = java.sql.Date.valueOf(date)
      val option = await(createTestShippingOption())
      val option2 = await(createTestShippingOption())

      // Create ranking/ restrictions
      val dateUpdate: java.sql.Date = java.sql.Date.valueOf("2016-02-15")
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)
      val stageId = await(database.createDBStage(stage))
      val resId = await(createRestriction(javaDate, true, stageId, option.avId))

      // Get restrictions for comparison
      val expectedResult = await(deliveryRestrictions.get(List(option.avId, option2.avId), "2016-01-14", "2016-02-16", List(stage.code)))

      // Delete/update restrictions
      val resUpdate = DeliveryRestrictionUpdate("insert",  DeliveryRestriction(date, option2.avId, stage.code))
      val resUpdate2 = DeliveryRestrictionUpdate("delete",  DeliveryRestriction(date, option2.avId, "INVALID STAGE!!"))

      // Ensure not found exception is thrown
      await(deliveryRestrictions.update(Seq(resUpdate, resUpdate2))) must throwA[NotFoundException]

      // Ensure rollback is successful
      val result = await(deliveryRestrictions.get(List(option.avId, option2.avId), "2016-01-14", "2016-02-16", List(stage.code)))
      result mustEqual expectedResult
    }
    "Throw error when operation is invalid" in new TestSlickDeliveryRestrictions with TestRestriction {
      // Create Date
      val dateString = "2016-01-15"
      val date: java.sql.Date = java.sql.Date.valueOf(dateString)
      // Create Options
      val option = await(createTestShippingOption())
      val option2 = await(createTestShippingOption())

      // Create ranking/ restrictions
      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)
      val stageId = await(database.createDBStage(stage))
      val resId = await(createRestriction(date, true, stageId, option.avId))

      val resUpdate = DeliveryRestrictionUpdate("INVALID OPERATION",  DeliveryRestriction(dateString, option2.avId, stage.code))

      // Ensure not found exception is thrown
      await(deliveryRestrictions.update(Seq(resUpdate))) must throwA[InvalidRequestException]

    }
//    "Convert java.util.date to appropriate string format" in new TestSlickDeliveryRestrictions {
//      val date: java.sql.Date = java.sql.Date.valueOf("2016-01-15")
//      deliveryRestrictions.sq
//    }
  }

  "Get Delivery restrictions for AMQ messages" should {
    "Return an empty list when there are no restrictions within the date range" in new TestSlickDeliveryRestrictions with TestShippingOption {
      val result = await(deliveryRestrictions.getAmqChannelRestrictions(RestrictionWindow("2018-10-20", "2018-10-23")))
      result mustEqual List.empty
    }

    "Return restriction that lies within the selected date range" in new TestSlickDeliveryRestrictions with TestRestriction {
      val restrictedWindow = RestrictionWindow("2018-10-21", "2018-10-21")
      val restrictedDate = "2018-10-21"

      val option = await(createTestShippingOption())

      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)

      // Create Restriction and Stage in DB and get availability
      val stageID = await(database.createDBStage(stage))
      await(createRestriction(java.sql.Date.valueOf(restrictedDate), true, stageID, option.avId))

      val avOption = await(database.readAvailability(option.avId))

      avOption match {
        case Some(av) =>
          val busCode = await(database.readBusiness(av.businessId))
          val expectedResult =
            Seq(AmqChannelRestriction(
                  AmqDeliveryRestriction(restrictedDate, stage.code, av.legacySku),
                  busCode))
          val result = await(deliveryRestrictions.getAmqChannelRestrictions(restrictedWindow))
          result mustEqual expectedResult
        case None => false

      }
      // Tidy up restriction
      val deleteRes = DeliveryRestrictionUpdate("delete", DeliveryRestriction(restrictedDate,option.avId,stage.code))
      await(deliveryRestrictions.update(Seq(deleteRes)))
    }
    "Not include a restriction which is not enabled" in new TestSlickDeliveryRestrictions with TestRestriction {
      val restrictedWindow = RestrictionWindow("2018-10-22", "2018-10-22")
      val restrictedDate = "2018-10-22"

      val option = await(createTestShippingOption())

      val ranking = await(database.genStageRank)
      val stage = TestStage(ranking + 1)

      // Create Restriction and Stage in DB and get availability
      val stageID = await(database.createDBStage(stage))
      await(createRestriction(java.sql.Date.valueOf(restrictedDate), false, stageID, option.avId))

      val avOption = await(database.readAvailability(option.avId))

      avOption match {
        case Some(av) =>
          val result = await(deliveryRestrictions.getAmqChannelRestrictions(restrictedWindow))
          result mustEqual List.empty
        case None => false
      }

      val deleteRes = DeliveryRestrictionUpdate("delete", DeliveryRestriction(restrictedDate,option.avId,stage.code))
      await(deliveryRestrictions.update(Seq(deleteRes)))
    }
  }
}
