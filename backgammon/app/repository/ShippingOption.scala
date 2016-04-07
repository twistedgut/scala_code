package repository

import domain.options.ShippingOptionUpdate

import scala.concurrent.Future

trait ShippingOption {
  val shippingOption: ShippingOptionRepository

  trait ShippingOptionRepository {

    /**
     * Returns all shipping options.
     */

    def updateOption(avId: Int, shippingOptionUpdate:  ShippingOptionUpdate): Future[Int]

  }

}