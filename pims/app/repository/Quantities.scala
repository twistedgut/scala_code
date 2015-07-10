package repository

import domain._
import scala.concurrent._

trait Quantities {
  val quantities: QuantityRepository

  trait QuantityRepository {
    /**
     * Search the database for the quantity with the specified box code.
     */
    def read(code: String): Future[BoxQuantity]

    /**
     * Increment or decrement the quantity of the box with the specified box code in the database.
     *
     * @returns `Success(quantity)` or `Failure(NotFoundException())`.
     */
    def inc(code: String, uq: UpdateQuantity): Future[Unit]
    def dec(code: String, uq: UpdateQuantity): Future[Unit]
//    def dec(code: String, quant: Quantity)(implicit ec: ExecutionContext): Future[Quantity]

  }
}
