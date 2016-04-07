package repository

import domain.ShippingOptionSearchResult

import scala.concurrent.Future

trait Options {
  val options: OptionRepository

  trait OptionRepository {

    /**
     * Returns all shipping options.
     */
    def search(): Future[Seq[ShippingOptionSearchResult]]

  }

}