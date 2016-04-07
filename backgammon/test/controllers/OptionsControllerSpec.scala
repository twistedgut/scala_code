package controllers

import domain.ShippingOptionSearchResult
import domain.auth.{HasAuthManager, Role, AuthManager}
import org.specs2.mock.Mockito
import org.specs2.specification.Scope
import play.api.libs.json.{JsBoolean, Json}
import play.api.mvc._
import play.api.test.{FakeRequest, PlaySpecification}
import repository._
import test.Counter
import domain._

import scala.concurrent.Future

class OptionsControllerSpec extends PlaySpecification with Mockito {

  trait MockShippingOptions extends Options {
    override val options = mock[OptionRepository]
  }

  trait MockAuthManager extends HasAuthManager {
    override implicit val authManager :AuthManager = new AuthManager {
      override def isAuthorised[A](request: Request[A], roles: Role*): Boolean = true
    }
  }

  trait TestEndpoint extends Controller with OptionsController with MockShippingOptions with MockAuthManager with Scope

  val constructSearchPageData = Counter { suffix =>
    ShippingOptionSearchResult(
      suffix.toInt,
      s"Option Name $suffix",
      Some(s"Country Name $suffix"),
      Some(s"Division Name $suffix"),
      Some(s"PostCodeGroup Name $suffix"),
      s"DC $suffix",
      BigDecimal(suffix),
      "Currency Name $suffix",
      suffix.toInt,
      1 == suffix % 2,
      1 == suffix % 2,
      Some(s"Business Name $suffix"),
      1 == suffix % 2,
      suffix.toInt
    )
  }

  "/searchShippingOptions" should {

    "return all shipping options" in new TestEndpoint {

      val searchPageData1 = constructSearchPageData.next()
      val searchPageData2 = constructSearchPageData.next()

      implicit val fR = FakeRequest("GET", "/shipping/options")
      val expectedResult = Future.successful { Ok(buildResponse(Seq(searchPageData1, searchPageData2))) }

      // mock the function the controller calls
      options.search() returns Future.successful(Seq(searchPageData1, searchPageData2))

      // make the request
      val infoResult: Future[Result] = searchShippingOptions().apply(fR)

      // test the result
      contentAsJson(infoResult) mustEqual contentAsJson(expectedResult)
      status(infoResult)        mustEqual 200
    }
  }
}
