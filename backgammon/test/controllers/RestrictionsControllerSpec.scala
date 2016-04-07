package controllers

import activemq.{AmqAkkaActor, AmqResendMessageProducer}
import domain._
import activemq._
import domain.auth.{AuthManager, HasAuthManager, Role}
import domain.deliveryrestrictions.DeliveryRestrictionResend
import helpers.TestResponses
import org.specs2.mock.Mockito
import org.specs2.specification.Scope
import play.api.libs.iteratee.Iteratee
import play.api.libs.json._
import play.api.mvc._
import play.api.test.Helpers._
import play.api.test.{FakeRequest, PlaySpecification, WithApplication}
import repository._

import scala.concurrent.Future


class RestrictionsControllerSpec extends PlaySpecification with Mockito {
  trait MockRestriction extends DeliveryRestrictions {
    override val deliveryRestrictions = mock[RestrictionsRepository]
  }

  trait MockAuthManager extends HasAuthManager {
    override implicit val authManager :AuthManager = new AuthManager {
      override def isAuthorised[A](request: Request[A], roles: Role*): Boolean = true
    }
  }

  trait TestEndpoint extends Controller with RestrictionsController with MockRestriction with AmqAkkaActor with TestResponses with Scope with MockAuthManager

  "/shipping/restrictions" should {
    "return restrictions for a given option and date range" in new TestEndpoint {

      val expectedResponse = fakeShippingRestrictionsSearchResult.next()
      val avIds            = List(1,2)

      implicit val fR = FakeRequest(GET, "/restrictions/delivery?shippingAvailabilityIds=1shippingAvailabilityIds=2&fromDate=date1&toDate=date2&stages=myStage")

      val ER: Future[Result] = Future.successful { Ok(buildResponse(Seq(expectedResponse))) }

      deliveryRestrictions.get(avIds, "date1", "date2", List("myStage")) returns Future.successful(Seq(expectedResponse))

      val result: Future[Result] = get(avIds, "date1", "date2", List("myStage")).apply(fR)

      status(result)        must_=== OK
      contentType(result)   must_=== Some("application/json")
      contentAsJson(result) must_=== contentAsJson(ER)

    }
  }
  "update and delete restrictions successfully" in new TestEndpoint {
    val restriction = fakeRestrictionUpdate.next()
    val updateBody: JsValue  = Json.toJson(Seq(restriction))
    deliveryRestrictions.update(Seq(restriction)) returns Future.successful(true)

    // faked data for AMQ message
    deliveryRestrictions.getRestrictionWindow(Seq(restriction)) returns RestrictionWindow("2016-02-09", "2016-02-10")
    val window = deliveryRestrictions.getRestrictionWindow(Seq(restriction))
    deliveryRestrictions.getAvailabilityDc(restriction) returns Future.successful("DC1")
    deliveryRestrictions.getAmqChannelRestrictions(window) returns
      Future.successful(Seq(AmqChannelRestriction(AmqDeliveryRestriction("2016-02-09", "transit", "fakesku"), "NAP")))

    implicit val fakeR: FakeRequest[AnyContentAsJson] = FakeRequest(PUT, "/restrictions/delivery").withBody(AnyContentAsJson(updateBody))
    val expectedResult = Future.successful { Ok(buildResponse(true)) }

    val result: Future[Result] = update().apply(fakeR)

    status(result)        must_=== OK
    contentType(result)   must_=== Some("application/json")
    contentAsJson(result) must_=== contentAsJson(expectedResult)
  }
  "Throw a 400 if the request body is invalid" in new TestEndpoint {
    val updateBody = Json.toJson("INVALID REQUEST")

    implicit val fakeR    = FakeRequest(PUT, "/restrictions/delivery").withBody(AnyContentAsJson(updateBody))
    val expectedResult = Future.successful(BadRequest("Invalid request"))

    val result: Future[Result] = update().apply(fakeR)

    status(result)        must_=== 400
    contentAsJson(result) must_=== contentAsJson(expectedResult)

  }
  "Throw a 500 if the request body is invalid" in new TestEndpoint {
    val restriction = fakeRestrictionUpdate.next()
    val updateBody  = Json.toJson(Seq(restriction))

    deliveryRestrictions.update(Seq(restriction)) returns Future.failed(FailedUpdateException("Availability", "availabilityId"))

    implicit val fR = FakeRequest(PUT, "/restrictions/delivery").withBody(AnyContentAsJson(updateBody))

    await(update().apply(fR)) must throwA[FailedUpdateException]
  }

  "/restrictions/resend" should {
    "complete successfully where the dates and dc provided are valid"  in new TestEndpoint {
      val date             = "2016-02-29"
      val expectedResponse = Json.obj(
        "uri"       -> "/restrictions/resend",
        "success"   -> JsBoolean(true),
        "error_msg" -> ""
      )
      val res      = DeliveryRestrictionResend(date,date, "DC1")
      val resJson  = Json.toJson(res)
      val window           = RestrictionWindow(date, date)
      val restriction      = Seq(AmqChannelRestriction(AmqDeliveryRestriction("2016-02-29", "delivery", "fakesku"), "NAP"))
      deliveryRestrictions.resend(res) returns
        Future.successful(AmqResendMessageProducer("DC1", window, restriction, amqActorSystem))
      implicit val fakeR: FakeRequest[AnyContentAsJson] = FakeRequest(POST, "/restrictions/resend").withBody(AnyContentAsJson(resJson))
      val result: Future[Result] = resend().apply(fakeR)
      status(result)        must_=== OK
      contentType(result)   must_=== Some("application/json")
      contentAsJson(result) must_=== expectedResponse
    }
  }

  "return 400 where a provided date is not valid"  in new TestEndpoint {
    val validDate              = "2016-02-29"
    val nonValidDate           = "2016-23-32"
    val res                    = DeliveryRestrictionResend(validDate, nonValidDate, "DC1")
    val resJson                = Json.toJson(res)
    implicit val fakeR         = FakeRequest(POST, "/restrictions/resend").withBody(AnyContentAsJson(resJson))
    val result: Future[Result] = resend().apply(fakeR)
    status(result)             must_=== 400
  }

  "return 400 where the from date is later than the to date"  in new TestEndpoint {
    val fromDate               = "2016-03-01"
    val toDate                 = "2016-02-29"
    val res                    = DeliveryRestrictionResend(fromDate, toDate, "DC1")
    val resJson                = Json.toJson(res)
    implicit val fakeR         = FakeRequest(POST, "/restrictions/resend").withBody(AnyContentAsJson(resJson))
    val result: Future[Result] = resend().apply(fakeR)
    status(result)             must_=== 400
  }

  "return 400 where the dc provided is not found in configuration"  in new TestEndpoint {
    val fromDate               = "2016-02-01"
    val toDate                 = "2016-02-29"
    val res                    = DeliveryRestrictionResend(fromDate, toDate, "XC9CX")
    val resJson                = Json.toJson(res)
    implicit val fakeR         = FakeRequest(POST, "/restrictions/resend").withBody(AnyContentAsJson(resJson))
    val result: Future[Result] = resend().apply(fakeR)
    status(result)             must_=== 400
  }

}
