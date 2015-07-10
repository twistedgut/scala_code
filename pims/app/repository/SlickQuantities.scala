package repository

import domain._
import scala.concurrent.Future
import play.api.libs.concurrent.Execution.Implicits.defaultContext

trait SlickQuantities extends Quantities {
  self: SlickTables with SlickDatabase =>

  val quantities = new QuantityDatabase

  class QuantityDatabase extends QuantityRepository {
    import driver.api._

    override def read(code: String): Future[BoxQuantity] = {
      val query = boxQuantityQuery(code)
      val action =
        query.result.head.map {
          case (boxId, boxName, boxCode, quantity) =>
            BoxQuantity(boxName, boxCode, quantity)

        }

      db.run(action)
    }

    override def inc(boxCode: String, uq: UpdateQuantity): Future[Unit] = update(boxCode, uq.quantity)

    override def dec(boxCode: String, uq: UpdateQuantity): Future[Unit] = update(boxCode, -uq.quantity)

    private def boxQuantityQuery(code: String) = {
      for {
        box       <- boxesTable if box.code === code
        quantity  <- quantityTable if quantity.box_id === box.id
      } yield ( box.id, box.name, box.code, quantity.quantity )
    }

    private def update(boxCode: String, uq: Int): Future[Unit] = {
      val query = boxQuantityQuery(boxCode)
      val action =
        query.result.head.flatMap {
          case (boxId, name, code, quantity) =>
            quantityTable.
              filter(_.box_id === boxId).
              map(row => row.quantity).
              update(quantity + uq).
              map(row => ())
          case (_) => DBIO.failed(NotFoundException("Box", boxCode))
        }
      db.run(action)
    }
  }
}
