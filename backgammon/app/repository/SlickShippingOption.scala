package repository

import database.Tables
import domain.options.{ShippingOptionUpdate}
import slick.dbio.Effect.{Write, Read}
import scala.concurrent.ExecutionContext.Implicits.global
import slick.profile.FixedSqlAction
import com.typesafe.scalalogging.StrictLogging

import scala.concurrent.Future

trait SlickShippingOption extends ShippingOption {
  this: Tables with SlickDatabase =>

  override val shippingOption = new ShippingOptionDatabase

  class ShippingOptionDatabase extends ShippingOptionRepository with StrictLogging {

    import profile.api._

    def updateOption(avId: Int, s: ShippingOptionUpdate) = {

      db.run(
        for{
          currency     <- Currency.filter(_.code === s.currencyCode).result.headOption
          availability <- updateAvailability(avId, s.signatureRequiredStatusId, s.isEnabled, s.isCustomerFacing, s.price, currency.map(_.id), s.isTaxInc)
        } yield availability
      ).map         { x      => logger.info("Updating shipping option ( message: Success)"); x }
       .recoverWith { case e => logger.error("Updating shipping options ( message: Failed, $e )"); Future.failed(e) }
    }

    private def updateAvailability(availabilityId: Int, signatureRequiredStatusId: Int, isEnabled: Boolean, isCustomerFacing: Boolean, price: BigDecimal, currencyIdOpt: Option[Int], isTaxInc: Boolean) = {

      currencyIdOpt match {
        case Some(currencyId) => {
          val query: FixedSqlAction[Int, NoStream, Write] = Availability.filter(_.id === availabilityId)
            .map(o => (o.isEnabled, o.isCustomerFacing, o.price, o.currencyId, o.signatureRequiredStatusId, o.doesPriceIncludeTax))
            .update((isEnabled, isCustomerFacing, price, currencyId, signatureRequiredStatusId, isTaxInc))

          query.flatMap[Int, NoStream, Effect.All]{
            case 1 => DBIO.successful(1)
            case _ => logger.error(s"Updating availability ( message: Update failed. ID = $availabilityId")
              DBIO.failed(FailedUpdateException("Availability", availabilityId.toString))

          }
        }
        case _ => logger.error("Updating availability ( message: Currency does not exist ) ")
          DBIO.failed(FailedUpdateException("Currency does not exist", availabilityId.toString))
      }
    }
  }
}