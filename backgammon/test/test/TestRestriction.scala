package test

object TestRestriction {

  case class SmcRestriction(restrictedDate: java.sql.Date, availabilityId: Int, stageId: Int, isRestricted: Boolean)

  //Todo: Hardcoded DC - get real one when endpoint becomes available

  def apply(restrictedDate: java.sql.Date, availabilityId: Int, stageId: Int, isRestricted: Boolean) = {
    SmcRestriction(restrictedDate, availabilityId, stageId, isRestricted)
  }
}