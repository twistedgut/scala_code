package auth

import org.specs2.mutable._
import play.api.libs.json._
import play.api.mvc._
import play.api.test._
import scala.concurrent.Future
import play.api.test.Helpers._

class AuthControllerSpec extends Specification with Results {

  "/auth/login_info" should {
    "return false when not logged in" in new WithApplication {

      val expectedResult = Json.obj(
        "uri" -> "/auth/login_info",
        "success" -> JsBoolean(true),
        "responseBody" -> Json.obj(
          "username" -> "",
          "is_logged_in" -> JsBoolean(false),
          "is_admin" -> JsBoolean(false)
        ),
        "error_msg" -> ""
      )

      val result: Future[Result] = route(FakeRequest(GET, "/auth/login_info")).get
      contentAsJson(result) must_== expectedResult
    }
  }

  "/auth/login" should {
    "log in an (regular) user in with good credentials" in new WithApplication {

      val loginDetails = Json.obj(
        "username" -> "hellouser",
        "password" -> "secret123"
      )

      val expectedLoginResult = Json.obj(
        "uri" -> "/auth/login",
        "success" -> JsBoolean(true),
        "error_msg" -> ""
      )

      val request = FakeRequest(POST, "/auth/login").withJsonBody(loginDetails)

      val result: Future[Result] = route(request).get
      contentAsJson(result) must_== expectedLoginResult

      val userSession = new Session(Map(
        "username" -> "hellouser",
        "is_admin" -> "false"
      ))
      session(result) must_=== userSession

      // now check /auth/login_info reflects this ok
      val expectedInfoResult = Json.obj(
        "uri" -> "/auth/login_info",
        "success" -> JsBoolean(true),
        "responseBody" -> Json.obj(
          "username" -> "hello",
          "is_logged_in" -> JsBoolean(true),
          "is_admin" -> JsBoolean(false)
        ),
        "error_msg" -> ""
      )

      val infoRequest = FakeRequest(GET, "/auth/login_info").withSession(
        "username" -> "hello",
        "is_admin" -> "false"
      )
      val infoResult = route(infoRequest).get

      contentAsJson(infoResult) must_== expectedInfoResult
    }

    "log in an (admin) user in with good credentials" in new WithApplication {

      val loginDetails = Json.obj(
        "username" -> "hello",
        "password" -> "secret123"
      )

      val expectedLoginResult = Json.obj(
        "uri" -> "/auth/login",
        "success" -> JsBoolean(true),
        "error_msg" -> ""
      )

      val request = FakeRequest(POST, "/auth/login").withJsonBody(loginDetails)

      val result: Future[Result] = route(request).get
      contentAsJson(result) must_== expectedLoginResult

      val userSession = new Session(Map(
        "username" -> "hello",
        "is_admin" -> "true"
      ))
      session(result) must_=== userSession

      // now check /auth/login_info reflects this ok
      val expectedInfoResult = Json.obj(
        "uri" -> "/auth/login_info",
        "success" -> JsBoolean(true),
        "responseBody" -> Json.obj(
          "username" -> "hello",
          "is_logged_in" -> JsBoolean(true),
          "is_admin" -> JsBoolean(true)
        ),
        "error_msg" -> ""
      )

      val infoRequest = FakeRequest(GET, "/auth/login_info").withSession(
        "username" -> "hello",
        "is_admin" -> "true"
      )
      val infoResult = route(infoRequest).get

      contentAsJson(infoResult) must_== expectedInfoResult
    }

    "reject a user with bad credentials" in new WithApplication {
      val loginDetails = Json.obj(
        "username" -> "badusername",
        "password" -> "badpassword"
      )

      val expectedLoginResult = Json.obj(
        "uri" -> "/auth/login",
        "success" -> JsBoolean(false),
        "error_msg" -> "Bad Credentials"
      )

      val request = FakeRequest(POST, "/auth/login").withJsonBody(loginDetails)

      val result: Future[Result] = route(request).get
      contentAsJson(result) must_== expectedLoginResult

      session(result) must_=== new Session(Map()) // empty session.

      // now check /auth/login_info reflects this ok
      val expectedInfoResult = Json.obj(
        "uri" -> "/auth/login_info",
        "success" -> JsBoolean(true),
        "responseBody" -> Json.obj(
          "username" -> "",
          "is_logged_in" -> JsBoolean(false),
          "is_admin" -> JsBoolean(false)
        ),
        "error_msg" -> ""
      )

      val infoRequest = FakeRequest(GET, "/auth/login_info")
      val infoResult = route(infoRequest).get

      //I cannot tell if the function below does anything
      contentAsJson(infoResult) must_== expectedInfoResult
    }
  }

  "/auth/logout" should {
    "logout a user" in new WithApplication {

      val expectedLogoutResult = Json.obj(
        "uri" -> "/auth/logout",
        "success" -> JsBoolean(true),
        "error_msg" -> ""
      )


      val request = FakeRequest(POST, "/auth/logout").withSession(
        "username" -> "hello",
        "is_admin" -> "true"
      )

      val result: Future[Result] = route(request).get
      contentAsJson(result) must_== expectedLogoutResult

    }
  }
}
