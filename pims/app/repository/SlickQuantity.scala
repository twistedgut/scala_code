package repository

import domain.Quantity
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

import slick.driver.MySQLDriver.api._
//import slick.driver.H2Driver.api._

trait SlickQuantity extends Quantities {
  this: SlickTables with SlickDatabase =>

  override val quantityUpdate = new QuantityDatabase

  class QuantityDatabase extends QuantityRepository {

//    private def lookupBox(quantity: Quantity): Future[(Int)] = {
//      val query = for {
//        box <- boxesTable if box.code === quantity.boxCode
//      } yield(box.id)
//      db.run(query.result.head)
//    }
//
//    private def updateBoxQuantity(box_id: Int, quantity: Quantity): Future[Int] = {
//      db.run(quantityTable.filter(q => q.box_id === box_id).map(q => (q.box_id, q.quantity)).update((box_id, quantity.quantity)))
//    }
//
//    private def lookupBox(quantity: Quantity): Future[(Int)] = db.run {
//      for {
//        box <- boxesTable.filter(_.code === quantity.boxCode).result.head
//        result <- box match {
//        case (Some(upbox)) => DBIO.successful(true)
//        case (_) => DBIO.successful(false)
//      }
//      } yield result
//    }

    override def increment (quantity: Quantity) = {
//    override def increment (boxCode: String, quantity: Int) = {
    }

  }
}
