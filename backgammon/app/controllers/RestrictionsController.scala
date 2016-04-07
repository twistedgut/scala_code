package controllers

import java.text.SimpleDateFormat
import javax.ws.rs.QueryParam

import activemq.{AmqAkkaActor, AmqMessageProducer}
import com.typesafe.scalalogging.StrictLogging
import com.wordnik.swagger.annotations._
import domain._
import domain.activemq.{AmqDeliveryRestriction, RestrictionWindow}
import domain.auth._
import domain.deliveryrestrictions._
import play.api.libs.json.JsValue
import play.api.mvc.{Action, AnyContent, Controller}
import repository._

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future
import scala.util.{Failure, Success, Try}

trait RestrictionsController extends Controller with HasAuthManager with StrictLogging {
  this: DeliveryRestrictions with AmqAkkaActor =>

  @ApiOperation(
    nickname = "Get Restrictions",
    value = "Returns Restrictions",
    httpMethod = "GET",
    response = classOf[DeliveryRestriction],
    responseContainer = "List"
  )
  def get(
           @ApiParam(name = "shippingAvailabilityId", required = true, defaultValue = "101", allowMultiple = false) @QueryParam("shippingAvailabilityId") shippingAvailabilityIds: List[Int],
           @ApiParam(name = "fromDate", required = true, defaultValue = "2016-01-01") @QueryParam("fromDate") fromDate: String,
           @ApiParam(name = "toDate", required = true, defaultValue = "2016-02-04") @QueryParam("toDate") toDate: String,
           @ApiParam(name = "stage", required = true, defaultValue = "dispatch", allowMultiple = false) @QueryParam("stage") stages: List[String] // list of strings where strings can be "dispatch", "transit" or "delivery".
         ) = Authed(User) {
    Action.async { implicit request =>
      deliveryRestrictions.get(shippingAvailabilityIds, fromDate, toDate, stages)
        .map(res => Ok(buildResponse(res)))
    }
  }

  @ApiOperation(
    nickname = "Update Delivery Restrictions",
    value = "Update Delivery Restrictions",
    httpMethod = "PUT"
  )
  @ApiImplicitParams(Array(new ApiImplicitParam(dataType = "List[domain.deliveryrestrictions.DeliveryRestrictionUpdate]", paramType = "body")))
  def update(): Authed[AnyContent] = Authed(User) {
    Action.async { implicit request =>
      val updateBody: Option[Seq[DeliveryRestrictionUpdate]] = request.bodyAs[Seq[DeliveryRestrictionUpdate]]
      updateBody match {
        case Some(update) =>
          val futureBool = deliveryRestrictions.update(update)
          logger.info("Request for restriction update: ( username: %s, update: %s )".format(
            request.session.get("username").getOrElse("UNKNOWN"),
            update.map(getLogString).mkString(", ")
          ))
          futureBool map { updateRes =>
            if (updateRes) {
              val window = deliveryRestrictions.getRestrictionWindow(update)
              AmqMessageProducer(
                deliveryRestrictions.getAvailabilityDc(update.head),
                window,
                deliveryRestrictions.getAmqChannelRestrictions(window),
                amqActorSystem
              ).sendAmqMessages()
            }
            Ok(buildResponse(updateRes))
          }
        case None => Future.successful(BadRequest("Invalid request"))
      }
    }
  }

  @ApiOperation(
    nickname = "Resend Delivery Restrictions for date range",
    value = "Resend Delivery Restrictions for date range",
    httpMethod = "POST"
  )
  @ApiImplicitParams(Array(new ApiImplicitParam(dataType = "domain.deliveryrestrictions.DeliveryRestrictionResend", paramType = "body")))
  def resend(): Authed[AnyContent] = Authed(User) {
    Action.async { request =>
      val res: Option[DeliveryRestrictionResend] = request.bodyAs[DeliveryRestrictionResend]
      res match {
        case Some(resResend) =>
          //TODO slip in check that DC entered is in config
          val validDates = areValidDates(resResend.fromDate, resResend.toDate)
          val validDc    = isValidDc(resResend.dcCode)
          if (validDates && validDc) {
            val futureProd = deliveryRestrictions.resend(resResend)
            futureProd map {
              restrictions => restrictions.sendAmqMessages()
                Ok(APIResponse(
                  uri = request.path,
                  responseBody = None,
                  success = true,
                  error_msg = ""
                ))
            }
          } else {
            Future.successful(BadRequest(s"Invalid parameters provided, please check: " +
              s"from date = ${resResend.fromDate}, to date = ${resResend.toDate}, dc = ${resResend.dcCode}"))
          }
        case None => Future.successful(BadRequest("Invalid request"))
      }
    }
  }

  @ApiOperation(
    nickname = "Get AMQ Delivery Restrictions",
    value = "Returns Restrictions for AMQ messages",
    httpMethod = "GET",
    response = classOf[AmqDeliveryRestriction],
    responseContainer = "List"
  )
  def blah(
            @ApiParam(name = "op", required = true, defaultValue = "insert") @QueryParam("op") op: String,
            @ApiParam(name = "fromDate", required = true, defaultValue = "2016-01-01") @QueryParam("fromDate") fromDate: String,
            @ApiParam(name = "toDate", required = true, defaultValue = "2016-02-29") @QueryParam("toDate") toDate: String,
            @ApiParam(name = "dcCode", required = true, defaultValue = "DC1") @QueryParam("dcCode") dcCode: String
          ) = Authed(User) {
    Action.async { implicit request =>
      deliveryRestrictions.blah(op, fromDate, toDate, dcCode) map {
        updateRes =>
          if (updateRes) {
            val window = RestrictionWindow("2016-02-22", "2016-02-25")
            AmqMessageProducer(
              Future {
                dcCode
              },
              window,
              deliveryRestrictions.getAmqChannelRestrictions(window),
              amqActorSystem
            ).sendAmqMessages()
          }
          Ok(buildResponse(updateRes))
      }
    }
  }

  private def isValidDc(dc: String): Boolean = {
    val xtConf = SmcConfig.getConfig("xt_channel_idents")
    xtConf.hasPath(dc)
  }

  private def areValidDates(fromDate: String, toDate: String): Boolean = {
    val format = new SimpleDateFormat("yyyy-MM-dd")
    format.setLenient(false)

    val tryParse = for {
      fromTime <- Try(format.parse(fromDate).getTime)
      toTime <- Try(format.parse(toDate).getTime)
    } yield (fromTime, toTime)

    tryParse match {
      case Success((fromParse, toParse)) =>
        fromParse <= toParse
      case Failure(ex) =>
        false
    }
  }

  private def getLogString(dru: DeliveryRestrictionUpdate) = {
    val res = dru.restriction
    s"Restriction: (operation: ${dru.operation}, id: ${res.availabilityId}, stage: ${res.stage}, date: ${res.restrictedDate})"
  }

}

@Api(value = "/restrictions/delivery")
class RestrictionsControllerImpl extends SmcController
  with RestrictionsController
  with DefaultAuthManagerImplementation
  with AmqAkkaActor
