package repository

import domain.DistributionCentre
import scala.concurrent.{ ExecutionContext, Future }

trait SlickDistributionCentres extends DistributionCentres {
  self: SlickTables with SlickDatabase =>

  val distributionCentres = new DistributionCentreDatabase

  class DistributionCentreDatabase extends DistributionCentreRepository {
    import driver.api._

    override def search()(implicit ec: ExecutionContext): Future[Seq[DistributionCentre]] = {
      db.run {
        distributionCentreTable.
          sortBy(_.code).
          result.
          map(_ map createDc)
      }
    }

    override def create(dc: DistributionCentre)(implicit ec: ExecutionContext): Future[DistributionCentre] = {
      db.run {
        // See if the DC exists:
        val existsAction =
          distributionCentreTable.filter(_.code === dc.code).result.headOption

        existsAction.flatMap[DistributionCentre, NoStream, Effect.All] {
          // If it exists, fail:
          case Some(_) =>
            DBIO.failed(AlreadyExistsException("DC", dc.code))

          // If it doesn't exist, insert the DC and succeed:
          case None =>
            (distributionCentreTable += (-1, dc.code, dc.name)).map(_ => dc)
        }
      }
    }

    override def read(code: String)(implicit ec: ExecutionContext): Future[Option[DistributionCentre]] = {
      db.run {
        distributionCentreTable.
          filter(_.code === code).
          result.
          headOption.
          map(_ map createDc)
      }
    }

    override def update(code: String, dc: DistributionCentre)(implicit ec: ExecutionContext): Future[DistributionCentre] = {
      db.run {
        // See if the DC exists:
        val existsAction =
          distributionCentreTable.filter(_.code === code).result.headOption

        existsAction.flatMap[DistributionCentre, NoStream, Effect.All] {
          // If it does, update it and return a Right:
          case Some((id, code, name)) =>
            distributionCentreTable.
              filter(_.id === id).
              map(row => (row.code, row.name)).
              update((dc.code, dc.name)).
              map(row => dc)

          // Otherwise fail with a Left:
          case None =>
            DBIO.failed(NotFoundException("DC", code))
        }
      }
    }

    override def delete(code: String)(implicit ec: ExecutionContext): Future[Unit] = {
      db.run {
        distributionCentreTable.
          filter(_.code === code).
          delete.
          map(_ => ())
      }
    }

    private def createDc(row: (Int, String, String)): DistributionCentre = {
      row match {
        case (id, code, name) =>
          DistributionCentre(code, name)
      }
    }
  }
}
