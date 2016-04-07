package repository

import java.sql.Date
import java.text.SimpleDateFormat

import activemq._
import com.typesafe.scalalogging.StrictLogging
import database.Tables
import domain.activemq.{AmqChannelRestriction, AmqDeliveryRestriction, RestrictionWindow}
import domain.deliveryrestrictions.{DeliveryRestriction, DeliveryRestrictionResend, DeliveryRestrictionUpdate}
import slick.dbio.Effect.Write
import slick.profile.FixedSqlAction

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future
import scala.util.{Failure, Success, Try}

trait SlickDeliveryRestrictions extends DeliveryRestrictions {
  this: Tables with SlickDatabase =>
  override val deliveryRestrictions = new RestrictionsDatabase


  class RestrictionsDatabase extends RestrictionsRepository with StrictLogging with AmqAkkaActor {

    import profile.api._

    def get(shippingAvailabilityIds: List[Int], fromDateString: String, toDateString: String, stages: List[String]): Future[Seq[DeliveryRestriction]] = {
      val fromDate = stringToSqlDate(fromDateString)
      val toDate = stringToSqlDate(toDateString)
      val query =
        for {
          s <- Stage if s.code inSetBind stages
          r <- Restriction if (r.stageId === s.id) && (r.isRestricted === true) && (r.shippingAvailabilityId inSetBind shippingAvailabilityIds) && r.restrictedDate.isBetween(fromDate, toDate)
        } yield (s, r)

      db.run(query.result).map{
        seqRows => seqRows.map {
          case (stageRow, restrictionRow) =>
            logger.info(s"Getting delivery restrictions ( message: Successful )")
            DeliveryRestriction(
              sqlDateToString(restrictionRow.restrictedDate),
              restrictionRow.shippingAvailabilityId,
              stageRow.code
            )
        }
      }.recoverWith { case e => logger.error(s"Getting delivery restrictions ( message: Failed, $e"); Future.failed(e) }
    }

    def update(restrictions: Seq[DeliveryRestrictionUpdate]): Future[Boolean] = {
      val actions = restrictions.map {
        // Creating Restriction
        case restriction@DeliveryRestrictionUpdate("insert", _) =>
          (for {
            s <- getStage(restriction.restriction.stage)
            r <- createRestriction(stringToSqlDate(restriction.restriction.restrictedDate), restriction.restriction.availabilityId, s.id)
                  .map{ r => logger.info("Updating delivery restriction ( message: Created a restriction )"); r }
          } yield r).flatMap{
            case 1 => DBIO.successful(1)
            case _ => DBIO.failed(FailedCreateException("Restriction for date", restriction.restriction.restrictedDate.toString))
                          .map{ r => logger.error("Updating delivery restriction ( message: Failed to create a restriction )"); r }
          }
        // Deleting restriction
        case restriction@DeliveryRestrictionUpdate("delete", _) =>
          (for {
            s <- getStage(restriction.restriction.stage)
            r <- deleteRestriction(stringToSqlDate(restriction.restriction.restrictedDate), restriction.restriction.availabilityId, s.id)
              .map { r => logger.info("Updating delivery restrictions ( message: Deleted restriction successfully )"); r }
          } yield r).flatMap{
            case 1 => DBIO.successful(1)
            case _ => DBIO.failed(FailedDeleteException("Restriction for date", restriction.restriction.restrictedDate.toString))
                          .map{ r => logger.error("Updating delivery restriction ( message: Failed to delete delivery restriction )"); r }
          }
        case restriction@DeliveryRestrictionUpdate(_, _) =>
          DBIO.failed(InvalidRequestException("Operation", restriction.operation))
              .map{ r => logger.error("Updating delivery restriction ( message: No restrictions to update )"); r }
      }

      val combinedAction = DBIO.sequence(actions)
      val result = db.run(combinedAction.transactionally)
        .map         { x      => logger.info(s"Updating delivery restrictions ( message: Successful )"); x }
        .recoverWith { case e => logger.error(s"Getting delivery restrictions ( message: Failed, $e"); Future.failed(e) }

      // Successful if number of rows altered is equal to number of updates passed to method
      result.map(r => r.count(_ == 1) match {
        case a if a == restrictions.length => true
        case _                             => false
      })
    }

    def resend(resend: DeliveryRestrictionResend): Future[AmqResendMessageProducer] = {
      val window = RestrictionWindow(resend.fromDate, resend.toDate)
      val futureRes = deliveryRestrictions.getAmqChannelRestrictions(window)
      futureRes map { res =>
        AmqResendMessageProducer(
          resend.dcCode,
          window,
          res,
          amqActorSystem
        )
      }
    }

    private def createRestriction(date: java.sql.Date, avId: Int, stageId: Int) = {
      Restriction
        .map(r => (r.isRestricted, r.restrictedDate, r.shippingAvailabilityId, r.stageId)) +=(true, date, avId, stageId)
    }

    private def deleteRestriction(date: java.sql.Date, avId: Int, stageId: Int): FixedSqlAction[Int, NoStream, Write] = {
      Restriction
        .filter(_.shippingAvailabilityId === avId)
        .filter(_.stageId === stageId)
        .filter(_.restrictedDate === date)
        .delete
    }

    // Retrieves all restrictions required along with shipping charge skus for Amq messages
    def getAmqChannelRestrictions(restrictionWindow: RestrictionWindow): Future[Seq[AmqChannelRestriction]] = {
      val fromDate = stringToSqlDate(restrictionWindow.begin_date)
      val toDate = stringToSqlDate(restrictionWindow.end_date)
      val query =
        for {
          r <- Restriction if (r.isRestricted === true) && r.restrictedDate.isBetween(fromDate, toDate)
          s <- Stage if s.id === r.stageId
          (a, b) <- Availability join Business on (_.businessId === _.id)
                    if a.id === r.shippingAvailabilityId
        } yield (r, s, a, b)
      db.run(query.result)
        .map {
          seqRows => seqRows.map {
            case (restrictionRow, stageRow, availabilityRow, businessRow) =>
              AmqChannelRestriction(
                AmqDeliveryRestriction(
                restrictionRow.restrictedDate.toString,
                stageRow.code,
                availabilityRow.legacySku),
                businessRow.code
              )
          }
        }.recoverWith { case e => logger.error(s"Getting delivery restrictions for AMQ messaging ( message: Failed, $e");
            Future.failed(e) }
    }

    def blah(op: String, fromDateString: String, toDateString: String, dcCode: String): Future[Boolean] = {
      val resUpdate = DeliveryRestrictionUpdate(op,  DeliveryRestriction("2016-02-22", 780, "dispatch"))
      val resUpdate2 = DeliveryRestrictionUpdate(op,  DeliveryRestriction("2016-02-25", 780, "dispatch"))
      val resUpdate3 = DeliveryRestrictionUpdate(op,  DeliveryRestriction("2016-02-22", 700, "dispatch"))
      val resUpdate4 = DeliveryRestrictionUpdate(op,  DeliveryRestriction("2016-02-25", 700, "dispatch"))
      val resUpdate5 = DeliveryRestrictionUpdate(op,  DeliveryRestriction("2016-02-22", 710, "dispatch"))
      val resUpdate6 = DeliveryRestrictionUpdate(op,  DeliveryRestriction("2016-02-25", 710, "dispatch"))
      update(Seq(resUpdate, resUpdate2, resUpdate3, resUpdate4, resUpdate5, resUpdate6))
    }

    def getAvailabilityDc(res: DeliveryRestrictionUpdate): Future[String] = {
      db.run(
        Availability.filter(_.id === res.restriction.availabilityId).map(_.dc).result.head
      )
    }

    def getRestrictionWindow(restrictions: Seq[DeliveryRestrictionUpdate]): RestrictionWindow = {
      val uniqueDates = {
        restrictions.flatMap(e => List(e.restriction.restrictedDate)).distinct
      }
      val sortedDates = uniqueDates.sortBy(stringToSqlDate(_).getTime)
      RestrictionWindow(sortedDates.head.toString, sortedDates.last.toString)
    }

    private def stringToSqlDate(inputDate: String): java.sql.Date = {
      val format = new SimpleDateFormat("yyyy-MM-dd")
      val date = format.parse(inputDate)
      new java.sql.Date(date.getTime)
    }

    private def sqlDateToString(inputDate: java.sql.Date): String = {
      val format = new SimpleDateFormat("yyyy-MM-dd")
      format.format(inputDate)
    }

    private def getStage(stageCode: String) = {
      Stage.filter(s => s.code === stageCode).result.headOption
        .flatMap {
          case Some(stage) => DBIO.successful(stage)
          case None => logger.error("Updating delivery restriction ( message: Stage not found )")
            DBIO.failed(NotFoundException("Stage", stageCode))
      }
    }

    implicit class ExtendDate(val myDate: Rep[Date]) {
      def isBetween(fromDate: Rep[Date], toDate: Rep[Date]): Rep[Boolean] = {
        (fromDate <= myDate) && (toDate >= myDate)
      }
    }

  }

}
