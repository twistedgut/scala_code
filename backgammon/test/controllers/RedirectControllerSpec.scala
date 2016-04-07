package controllers

import org.specs2.mutable.Specification
import play.api.mvc.Results
import play.api.test.{WithApplication, FakeRequest}
import play.api.test.Helpers._

class RedirectControllerSpec extends Specification with Results {

  "/" should {
    "redirect to swagger documentation" in {
      val redirectController = new RedirectControllerImpl
      val result = redirectController.index().apply(FakeRequest())
      redirectLocation(result) must beSome.which(_ == "/docs/")
    }
  }

  "/redirect" should {
    "redirect to what-ever returnURL is set to" in new WithApplication {

      //basic test
      val TARGET_URL_1 = "xxx"
      val result = route(FakeRequest(GET, s"/redirect?returnURL=$TARGET_URL_1")).get
      redirectLocation(result) must beSome.which(_ == TARGET_URL_1)

      // this url is more accurate as it contains all the URL encoded characters: http://localhost:9000/?backend-tested=1
      val TARGET_URL_2_ENCODED = "http%3A%2F%2Flocalhost%3A9000%2F%3Fbackend_tested%3D1"
      val TARGET_URL_2_UNENCODED = "http://localhost:9000/?backend_tested=1"
      val result2 = route(FakeRequest(GET, s"/redirect?returnURL=$TARGET_URL_2_ENCODED")).get
      redirectLocation(result2) must beSome.which(_ == TARGET_URL_2_UNENCODED)

    }
  }
}
