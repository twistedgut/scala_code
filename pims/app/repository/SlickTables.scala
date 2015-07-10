package repository

trait SlickTables {
  this: SlickDatabase =>

  import driver.api._

  class BoxesTable(tag:Tag) extends Table[(Int, String, String, Int)](tag, "box") {
    def id = column[Int]("id", O.PrimaryKey, O.AutoInc)
    def code = column[String]("code")
    def name = column[String]("name")
    def dc_id = column[Int]("dc_id")

    def * = (id, code, name, dc_id)
  }

  val boxesTable = TableQuery[BoxesTable]

  class BusinessTable(tag:Tag) extends Table[(Int, String, String)](tag, "business") {
    def id = column[Int]("id", O.PrimaryKey, O.AutoInc)
    def code = column[String]("code")
    def name = column[String]("name")

    def * = (id, code, name)
  }

  val businessTable = TableQuery[BusinessTable]

  class BusinessToBoxTable(tag:Tag) extends Table[(Int, Int, Int)](tag, "link_business__box") {
    def id = column[Int]("id", O.PrimaryKey, O.AutoInc)
    def box_id = column[Int]("box_id")
    def business_id = column[Int]("business_id")

    def * = (id, box_id, business_id)
  }

  val businessToBoxTable = TableQuery[BusinessToBoxTable]

  class DistributionCentreTable(tag:Tag) extends Table[(Int, String, String)](tag, "dc") {
    def id = column[Int]("id", O.PrimaryKey, O.AutoInc)
    def code = column[String]("code")
    def name = column[String]("name")

    def * = (id, code, name)
  }

  val distributionCentreTable = TableQuery[DistributionCentreTable]

  class QuantityTable(tag:Tag) extends Table[(Int, Int, Int)](tag, "quantity") {
    def id = column[Int]("id", O.PrimaryKey, O.AutoInc)
    def box_id = column[Int]("box_id")
    def quantity = column[Int]("quantity")

    def * = (id, box_id, quantity)
  }

  val quantityTable = TableQuery[QuantityTable]

}
