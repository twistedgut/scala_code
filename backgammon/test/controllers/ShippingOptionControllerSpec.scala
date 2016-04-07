package controllers

import domain.auth.{Admin, AuthManager, HasAuthManager, Role, User}
import domain.options.ShippingOptionUpdate
import helpers.TestResponses
import org.specs2.mock.Mockito
import org.specs2.specification.Scope
import play.api.libs.json._
import play.api.mvc._
import play.api.test.{FakeRequest, PlaySpecification}
import repository.{ErrorMessageException, FailedUpdateException, ShippingOption}

import scala.concurrent.Future

class ShippingOptionControllerSpec extends PlaySpecification with Mockito {

  trait MockShippingOption extends ShippingOption {
    override val shippingOption = mock[ShippingOptionRepository]
  }

  trait MockAuthManager extends HasAuthManager {
    override implicit val authManager: AuthManager = new AuthManager {
      override def isAuthorised[A](request: Request[A], roles: Role*): Boolean = true
    }
  }

  trait TestEndpoint            extends Controller with ShippingOptionController with MockShippingOption with Scope with TestResponses with MockAuthManager
  trait TestEndpointWithoutAuth extends Controller with ShippingOptionController with MockShippingOption with Scope with TestResponses

  "/search/option/avId" should {
    "successfully read json format into case class" in new TestEndpoint {

      val json1 = Json.obj(
        "price"                     -> 5,
        "currencyCode"              -> "EUR",
        "signatureRequiredStatusId" -> 1,
        "isEnabled"                 -> true,
        "isCustomerFacing"          -> true,
        "isTaxInc"                  -> true
      )

      val json2 = Json.obj(
        "price"                     -> 5.50,
        "currencyCode"              -> "EUR",
        "signatureRequiredStatusId" -> 1,
        "isEnabled"                 -> true,
        "isCustomerFacing"          -> true,
        "isTaxInc"                  -> true
      )

      val json3 = Json.obj(
        "price"                     -> "5.50",
        "currencyCode"              -> "EUR",
        "signatureRequiredStatusId" -> 1,
        "isEnabled"                 -> true,
        "isCustomerFacing"          -> true,
        "isTaxInc"                  -> true
      )

      val json4 = Json.obj(
        "price"                     -> "",
        "currencyCode"              -> "EUR",
        "signatureRequiredStatusId" -> 1,
        "isEnabled"                 -> true,
        "isCustomerFacing"          -> true,
        "isTaxInc"                  -> true
      )

      json1.as[ShippingOptionUpdate] mustEqual ShippingOptionUpdate(true, true, 5, "EUR", 1, true)
      json2.as[ShippingOptionUpdate] mustEqual ShippingOptionUpdate(true, true, 5.50, "EUR", 1, true)
      json3.as[ShippingOptionUpdate] mustEqual ShippingOptionUpdate(true, true, 5.50, "EUR", 1, true)
      json4.as[ShippingOptionUpdate] must      throwA[JsResultException]
    }
    "update a shipping option succesfully" in new TestEndpoint {
      val avId        = 1
      val update      = fakeShippingOptionUpdate().next()
      val updateJson  = Json.toJson(update)

      shippingOption.updateOption(avId, update) returns Future.successful(1)

      implicit val fReeek            = FakeRequest(PUT, s"/shipping/option/$avId").withBody(AnyContentAsJson(updateJson))

      val result: Future[Result] = updateOption(avId).apply(fReeek)

      status(result) mustEqual 200

    }
    "Throw appropriate error message when update fails" in new TestEndpoint {
      val avId        = 1
      val update      = fakeShippingOptionUpdate().next()
      val updateJson  = Json.toJson(update)

      shippingOption.updateOption(avId, update) returns Future.failed(FailedUpdateException("Availability", avId.toString))

      val result = updateOption(avId).apply(FakeRequest(PUT, s"/shipping/option/$avId").withBody(AnyContentAsJson(updateJson)))

      await(result) must throwA[FailedUpdateException]
    }
    "returns 'Not Authorised' when a non-admin user tries to update" in new TestEndpointWithoutAuth {
      override implicit val authManager: AuthManager = new AuthManager {
        override def isAuthorised[A](request: Request[A], roles: Role*): Boolean =
          (isUser(request) && roles.contains(User)) || (isAdmin(request) && roles.contains(Admin))

        private def isUser[A](request: Request[A]) : Boolean = true

        private def isAdmin[A](request: Request[A]) :Boolean = false
      }

      val avId        = 1
      val update      = fakeShippingOptionUpdate().next()
      val updateJson  = Json.toJson(update)

      shippingOption.updateOption(avId, update) returns Future.successful(1)

      implicit val fR             = FakeRequest(PUT, s"/shipping/option/$avId").withBody(AnyContentAsJson(updateJson))
      val result: Future[Result]  = updateOption(avId).apply(fR)

      status(result) mustEqual 401
    }
  }
}