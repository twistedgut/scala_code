package repository

import domain.Box
import slick.dbio.Effect.{Write, Read}
import slick.profile.SqlAction
import scala.concurrent.Future
import play.api.libs.concurrent.Execution.Implicits.defaultContext

trait SlickBoxes extends Boxes {
  this: SlickTables with SlickDatabase =>

  override val boxes = new BoxesDatabase

  class BoxesDatabase extends BoxesRepository {

    import driver.api._

    val boxCode = """/(\w+)/\w+/\w+""".r

    private def lookupDcAndBusinessAction(box: Box, dcCode: String): DBIOAction[(Int, Int), NoStream, Effect.Read] = {
      val query = for {
        dc <- distributionCentreTable if dc.code === dcCode
        business <- businessTable if business.code === box.dc_code
      } yield(dc.id, business.id)

      query.result.head
    }

    private def insertBoxAction(box: Box, dcId: Int): DBIOAction[Int, NoStream, Effect.Write] = {
      (boxesTable returning boxesTable.map(_.id)) += ((-1, box.code, box.name, dcId))
    }

    private def insertAssociatedDataAction(boxId: Int, busId: Int): DBIOAction[Unit, NoStream, Effect.Write] = {
      DBIO.seq(
        businessToBoxTable += ((-1, boxId, busId)),
        quantityTable      += ((-1, boxId, 0))
      )
    }

    /**
     * Fetch the boxId for a given box code
     */
    def getBoxId(boxCode: String): SqlAction[Option[Int], NoStream, Read] =
      boxesTable
        .filter(_.code === boxCode)
        .map(_.id)
        .result
        .headOption

    override def store(box: Box): Future[Unit] = {
      box.code match {
        case boxCode(dc_code) => {
          val actions =
            for {
              (dc_id, bus_id) <- lookupDcAndBusinessAction(box, dc_code)
              box_id          <- insertBoxAction(box, dc_id)
              _               <- insertAssociatedDataAction(box_id, bus_id)
            } yield ()

          db.run(actions.transactionally)
        }
      }
    }
  }
}
