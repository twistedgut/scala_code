package controllers

import activemq.{AmqAkkaActor, AmqResendMessageProducer}
import domain._
import activemq._
import domain.auth.{AuthManager, HasAuthManager, Role}
import domain.deliveryrestrictions.DeliveryRestrictionResend
import helpers.TestResponses
import org.specs2.mock.Mockito
import org.specs2.specification.Scope
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
    val updateBody  = Json.toJson(Seq(restriction))

    deliveryRestrictions.update(Seq(restriction)) returns Future.successful(true)

    // faked data for AMQ message
    deliveryRestrictions.getRestrictionWindow(Seq(restriction)) returns RestrictionWindow("2016-02-09", "2016-02-10")
    val window = deliveryRestrictions.getRestrictionWindow(Seq(restriction))
    deliveryRestrictions.getAvailabilityDc(restriction) returns Future.successful("DC1")
    deliveryRestrictions.getAmqChannelRestrictions(window) returns
      Future.successful(Seq(AmqChannelRestriction(AmqDeliveryRestriction("2016-02-09", "transit", "fakesku"), "NAP")))

    implicit val fR = FakeRequest(PUT, "/restrictions/delivery").withBody(AnyContentAsJson(updateBody))
    val expectedResult = Future.successful { Ok(buildResponse(true)) }

    val result: Future[Result] = update().apply(fR)

    status(result)        must_=== OK
    contentType(result)   must_=== Some("application/json")
    contentAsJson(result) must_=== contentAsJson(expectedResult)
  }
  "Throw a 400 if the request body is invalid" in new TestEndpoint {
    val updateBody = Json.toJson("INVALID REQUEST")

    implicit val fR    = FakeRequest(PUT, "/restrictions/delivery").withBody(AnyContentAsJson(updateBody))
    val expectedResult = Future.successful(BadRequest("Invalid request"))

    val result: Future[Result] = update().apply(fR)

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
    "return true where the dates provided are valid"  in new TestEndpoint {
      val date             = "2016-02-29"

      val expectedResponse = Json.obj(
        "uri"       -> "/restrictions/resend",
        "success"   -> JsBoolean(true),
        "error_msg" -> ""
      )

//DeliveryRestrictionResend(date,date,"DC2")
      val res      = DeliveryRestrictionResend(date,date, "DC1")
      val resJson  = Json.toJson(res)

      val window           = RestrictionWindow(date, date)
      val restriction      = Seq(AmqChannelRestriction(AmqDeliveryRestriction("2016-02-09", "delivery", "fakesku"), "NAP"))

      deliveryRestrictions.resend(res) returns
        Future.successful(AmqResendMessageProducer("DC1", window, restriction, amqActorSystem))

//      val resResend = Json.parse(
//        """{
//           "fromDate" : "2016-02-29",
//           "toDate"   : "2016-02-29",
//           "dc"       : "DC1"
//        }""")
//
//      val resResend2 = Json.obj("fromDate" -> date, "toDate" -> date, "dc" -> "DC1")

      implicit val fakeR = FakeRequest(POST, "/restrictions/resend").withBody(AnyContentAsJson(resJson))
      val result: Future[Result] = rese  resend()
      update().apply(fR)




      //deliveryRestrictions.getAmqChannelRestrictions(window) returns Future.successful(restriction)


//      implicit val fR = FakeRequest(GET, s"/restrictions/resend?fromDate=$date&toDate=$date&dc=DC1")


      implicit val fR = FakeRequest(POST, "/restrictions/resend").withBody(AnyContentAsJson(resJson))
//      //val result2: Future[Result] = resend().apply(fR)
//
//
//      //val request = FakeRequest(POST, "/restrictions/resend").withJsonBody(resResend)
//
//      //val ER: Future[Result] = Future.successful { Ok(buildResponse(expectedResponse)) }
//
//      val result2: Future[Result] = resend().apply(FakeRequest(POST, "/restrictions/resend").withBody(AnyContentAsJson(triffJson))).run
//
//      status(result2)        must_=== OK
//      contentType(result2)   must_=== Some("application/json")
      expectedResponse must_=== expectedResponse
    }
  }





//  val restriction = fakeRestrictionUpdate.next()
//  val updateBody  = Json.toJson(Seq(restriction))
//
//  deliveryRestrictions.update(Seq(restriction)) returns Future.successful(true)
//
//  // faked data for AMQ message
//  deliveryRestrictions.getRestrictionWindow(Seq(restriction)) returns RestrictionWindow("2016-02-09", "2016-02-10")
//  val window = deliveryRestrictions.getRestrictionWindow(Seq(restriction))
//  deliveryRestrictions.getAvailabilityDc(restriction) returns Future.successful("DC1")
//  deliveryRestrictions.getAmqChannelRestrictions(window) returns
//    Future.successful(Seq(AmqChannelRestriction(AmqDeliveryRestriction("2016-02-09", "transit", "fakesku"), "NAP")))
//
//  implicit val fR = FakeRequest(PUT, "/restrictions/delivery").withBody(AnyContentAsJson(updateBody))
//  val expectedResult = Future.successful { Ok(buildResponse(true)) }
//
//  val result: Future[Result] = update().apply(fR)
//
//  status(result)        must_=== OK
//  contentType(result)   must_=== Some("application/json")
//  contentAsJson(result) must_=== contentAsJson(expectedResult)





//  case class DeliveryRestrictionResend(
//                                        fromDate: String,
//                                        toDate: String,
//                                        dcCode: String
//                                      )


//  def fakeShippingOptionUpdate() = {
//    Counter { suffix =>
//      ShippingOptionUpdate(
//        1 == suffix % 2,
//        1 == suffix % 2,
//        BigDecimal(suffix),
//        s"Currency code $suffix",
//        suffix.toInt,
//        1 == suffix % 2
//      )
//    }
//  }

//  val avId        = 1
//  val update      = fakeShippingOptionUpdate().next()
//  val updateJson  = Json.toJson(update)
//
//  shippingOption.updateOption(avId, update) returns Future.successful(1)
//
//  implicit val fR            = FakeRequest(PUT, s"/shipping/option/$avId").withBody(AnyContentAsJson(updateJson))
//  val result: Future[Result] = updateOption(avId).apply(fR)
//
//  status(result) mustEqual 200

//  case class ShippingOptionUpdate(
//                                   isEnabled                : Boolean,
//                                   isCustomerFacing         : Boolean,
//                                   price                    : BigDecimal,
//                                   currencyCode             : String,
//                                   signatureRequiredStatusId: Int,
//                                   isTaxInc                 : Boolean )



//  "return 400 where a provided date is not valid"  in new TestEndpoint {
//    val invalidDate            = "2016-22-30"
//    implicit val fR            = FakeRequest(GET, s"/restrictions/resend?fromDate=$invalidDate&toDate=$invalidDate&dc=DC1")
//    val result: Future[Result] = resend(invalidDate, invalidDate, "DC1").apply(fR)
//    status(result)             must_=== 400
//  }
//
//  "return 400 where the from date is later than the to date"  in new TestEndpoint {
//    val fromDate               = "2016-02-29"
//    val toDate                 = "2016-02-28"
//    implicit val fR            = FakeRequest(GET, s"/restrictions/resend?fromDate=$fromDate&toDate=$toDate&dc=DC1")
//    val result: Future[Result] = resend(fromDate, toDate, "DC1").apply(fR)
//    status(result)             must_=== 400
//  }

}
