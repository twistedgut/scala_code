package repository

import scala.math.BigDecimal.RoundingMode
import database.Tables
import domain.ShippingOptionSearchResult
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future
import com.typesafe.scalalogging.StrictLogging
import nap.helpers._

trait SlickOptions extends Options {
  this: Tables with SlickDatabase =>

  override val options = new OptionsDatabase

  class OptionsDatabase extends OptionRepository with StrictLogging {
    import profile.api._


    override def search(): Future[Seq[ShippingOptionSearchResult]] = db.run {
      val query =
        ShippingOption .join    (Availability) .on {case sh ~ ar                      => sh.id  === ar.optionId}
                       .joinLeft(Business)     .on {case sh ~ ar ~ b                  =>  b.id  === ar.businessId}
                       .joinLeft(Country)      .on {case sh ~ ar ~ b ~ c              => c.id   === ar.countryId}
                       .joinLeft(Division)     .on {case sh ~ ar ~ b ~ c ~ d          => d.id   === ar.divisionId}
                       .joinLeft(PostCodeGroup).on {case sh ~ ar ~ b ~ c ~ d ~ p      => p.id   === ar.postCodeGroupId}
                       .join    (Currency)     .on {case sh ~ ar ~ b ~ c ~ d ~ p ~ cy => cy.id  === ar.currencyId}

      query.result.map { seqOfTuples =>
        seqOfTuples.map {
          case ((((((sh, ar), b), c), d), p), cy) =>
            logger.info("Searching for shipping options ( message: Successful )")
            ShippingOptionSearchResult(
              avId = ar.id,
              optionName = sh.name,
              countryName = c.map(_.name),
              divisionName = d.map(_.name),
              postcodeGroupName = p.map(_.name),
              dcCode = ar.dc,
              price = ar.price.setScale(2, RoundingMode.HALF_UP),
              currencyName = cy.code,
              currencyId   = cy.id,
              isTaxInc = ar.doesPriceIncludeTax,
              isLive = ar.isEnabled,
              business = b.map(_.name),
              isCustomerFacing = ar.isCustomerFacing,
              isSignatureRequired = ar.signatureRequiredStatusId
            )
        }
      }
    }.recoverWith { case e => logger.error(s"Searching shipping options ( message: Failed, $e )"); Future.failed(e) }
  }
}