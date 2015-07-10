package integration

import org.specs2.mutable._
import org.specs2.runner._
import org.junit.runner._
import play.api.test._
import play.api.test.Helpers._
import scala.concurrent.Await
import scala.concurrent.duration._
import scala.util.Random

@RunWith(classOf[JUnitRunner])
class IntegrationSpec extends Specification {

  "Server" should {

    "start a pims instance" in new WithServer {
      WsTestClient.withClient { ws =>
        Await.result(ws.url(s"http://localhost:8080").get(), 10.seconds).status must_== OK
      }
    }

    "create a box" in {
      val code:String = Random.alphanumeric.take(3).mkString

      val body = s"""{
                    "code": "/dc1/inner/$code",
                    "name": "Box 1",
                    "dc_code": "bus1"
                 }"""

      WsTestClient.withClient { ws =>
        val response = ws.url(s"http://localhost:8080/box")
                            .withHeaders("Content-Type" -> "application/json")
                            .post(body)

        Await.result(response, 10.seconds).status must_== OK
      }
    }

  }
}
