package repository

import domain.Box
import scala.concurrent.Await
import scala.concurrent.duration._
import slick.jdbc.meta.MTable

trait TestDatabase {
  this: SlickTables with SlickDatabase =>

  import driver.api._

  object database {
    private val schema = (
        boxesTable.schema ++
        businessTable.schema ++
        businessToBoxTable.schema ++
        dataCentreTable.schema ++
        quantityTable.schema)
  
    def created = {
      clearDatabase
      val setup = DBIO.seq(
        schema.create,
        businessTable += (-1, "bus1", "Business 1"),
        dataCentreTable += (-1, "dc1", "Data Centre 1")
      )
      Await.result(db.run(setup), 1.seconds)
    }
  
    private def clearDatabase = {
      val setup = DBIO.seq(
        schema.drop
      )
      if(!Await.result(db.run(MTable.getTables), 1.seconds).toList.isEmpty) {
        Await.result(db.run(setup), 1.seconds)
      }
    }
  
    def boxForCode(code: String) = {
      val result = Await.result(
        db.run(boxesTable.filter(_.code === code).result.headOption),
        1.seconds
      )
  
      result match { 
        case Some((_: Int, code: String, name: String, _: Int)) => (code, name)
        case _ => None
      }
    }
  
    def businessesForBox(code: String): Seq[String] = {
      val query = for {
        box <- boxesTable if box.code === code
        link <- businessToBoxTable if box.id === link.box_id
        business <- businessTable if link.business_id === business.id
      } yield(business.code)
  
      Await.result(db.run(query.result), 1.seconds)
    }
  
    def dcForBox(code: String): Option[String] = {
      val query = for {
        box <- boxesTable if box.code === code
        dc <- dataCentreTable if box.dc_id === dc.id
      } yield(dc.code)
  
      Await.result(db.run(query.result.headOption), 1.seconds)
    }
  
    def quantity(code: String): Option[Int] = {
      val query = for {
        box <- boxesTable if box.code === code
        q <- quantityTable if box.id === q.box_id
      } yield(q.quantity)
  
      Await.result(db.run(query.result.headOption), 1.seconds)
    }
  }
}