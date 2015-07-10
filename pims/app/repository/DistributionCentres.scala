package repository

import domain._
import scala.concurrent._

trait DistributionCentres {
  val distributionCentres: DistributionCentreRepository

  trait DistributionCentreRepository {
    /**
     * Return a list of all distribution centres in the database.
     */
    def search()(implicit ec: ExecutionContext): Future[Seq[DistributionCentre]]

    /**
     * Attempt to create a new distribution centre in the database.
     *
     * @returns `Success(dc)` or `Failure(AlreadyExistsException())`.
     */
    def create(dc: DistributionCentre)(implicit ec: ExecutionContext): Future[DistributionCentre]

    /**
     * Search the database for a distribution centre with the specified `code`.
     */
    def read(code: String)(implicit ec: ExecutionContext): Future[Option[DistributionCentre]]

    /**
     * Update the distribution centre with the specified `code` in the database.
     * Set the relevant fields to the values in `dc`.
     *
     * @returns `Success(dc)` or `Failure(NotFoundException())`.
     */
    def update(code: String, dc: DistributionCentre)(implicit ec: ExecutionContext): Future[DistributionCentre]

    /**
     * Delete the distribution centre with the specified `code`.
     */
    def delete(code: String)(implicit ec: ExecutionContext): Future[Unit]
  }
}
