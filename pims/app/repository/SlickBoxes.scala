package repository

import domain.Box
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

import slick.driver.MySQLDriver.api._
//import slick.driver.H2Driver.api._

trait SlickBoxes extends Boxes {
  this: SlickTables with SlickDatabase =>

  override val boxes = new BoxesDatabase

  class BoxesDatabase extends BoxesRepository {

    val boxCode = """/(\w+)/\w+/\w+""".r

    private def lookupDcAndBusiness(box: Box, dc_code: String): Future[(Int, Int)] = {
      val query = for {
        dc <- dataCentreTable if dc.code === dc_code
        business <- businessTable if business.code === box.business_code
      } yield(dc.id, business.id)

      db.run(query.result.head)
    }

    private def insertBox(box: Box, dc_id: Int): Future[Int] = {
      db.run((boxesTable returning boxesTable.map(_.id)) += ((-1, box.code, box.name, dc_id)))
    }

    private def insertAssociatedData(box_id: Int, bus_id: Int): Future[Unit] = {
      val insert =
        DBIO.seq(
          businessToBoxTable += ((-1, box_id, bus_id)),
          quantityTable += ((-1, box_id, 0))
        )

      db.run(insert)
    }

    override def store(box: Box) = {
      box.code match {
        case boxCode(dc_code) => {
          for {
            (dc_id, bus_id) <- lookupDcAndBusiness(box, dc_code)
            box_id <- insertBox(box, dc_id)
            _ <- insertAssociatedData(box_id, bus_id)
          } yield()
        }
      }

    }

  }

}
