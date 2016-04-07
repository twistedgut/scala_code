package controllers

import javax.ws.rs.PathParam

import com.typesafe.scalalogging.StrictLogging
import com.wordnik.swagger.annotations._
import domain._
import domain.auth._
import domain.deliveryrestrictions.DeliveryRestrictionUpdate
import domain.options.ShippingOptionUpdate
import play.api.mvc.{Action, Controller}
import repository._

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

trait ShippingOptionController extends Controller with HasAuthManager with StrictLogging {
  this: ShippingOption =>

  @ApiOperation(nickname = "updateOption", value = "updateOption", httpMethod = "PUT")
  @ApiImplicitParams(Array(new ApiImplicitParam(dataType = "domain.options.ShippingOptionUpdate", paramType = "body")))
  def updateOption(@ApiParam(value = "Availability identifer") @PathParam("avId") avId: Int) = Authed(Admin) {
    Action.async { implicit request =>
      val update = request.bodyAs[ShippingOptionUpdate]
      logger.info("Request for shipping option update: ( username: %s, update: %s )".format(
        request.session.get("username").getOrElse("UNKNOWN"),
        update.map(getLogString).mkString(", ")
      ))
      update match {
        case Some(option) => shippingOption.updateOption(avId, option) map (r => Ok(buildResponse(r)))
        case _            => Future.failed(ErrorMessageException("Cannot accept that payload - check api documentation for required payload"))
      }
    }
  }

  def getLogString (sou: ShippingOptionUpdate) = {
    s"Shipping option: (isEnabled: ${sou.isEnabled}, isCustomerFacing: ${sou.isCustomerFacing}, price: ${sou.price}, " +
      s"currencyCode: ${sou.currencyCode}, signatureRequiredStatusId: ${sou.signatureRequiredStatusId}, isTaxInc: ${sou.isTaxInc})"
  }
}

@Api(value = "/shipping/option")
class ShippingOptionControllerImpl extends SmcController
                                      with ShippingOptionController
                                      with DefaultAuthManagerImplementation