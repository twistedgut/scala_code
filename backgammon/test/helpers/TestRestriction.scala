package helpers

import repository.TestDatabase
import test._


trait TestRestriction extends TestShippingOption {
  this: TestDatabase =>

  def createRestriction(date: java.sql.Date, isRestricted: Boolean, stageId: Int, avId: Int) = {
    database.createDBRestriction(TestRestriction(date, avId, stageId, isRestricted))
  }
}
