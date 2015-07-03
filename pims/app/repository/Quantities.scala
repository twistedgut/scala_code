package repository

import domain.Quantity
import scala.concurrent.Future

trait Quantities {

  val quantityUpdate: QuantityRepository

  trait QuantityRepository {
    def increment(quantity: Quantity): Future[Boolean]
  }

}
