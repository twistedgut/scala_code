package integration

import controllers.Formats
import domain._
import repository._

import org.specs2.mock.Mockito
import org.specs2.mutable.Specification
import org.specs2.specification.Scope
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import play.api.libs.json._
import play.api.mvc.{Result, Results}
import play.api.test._
import play.api.test.Helpers._
import play.api.libs.ws.WSClient
import scala.concurrent.duration._
import scala.concurrent.{Await, Future, ExecutionContext}

class DistributionCentreSpec extends Specification with Formats {
  val createDc = Counter { suffix =>
    val codeSuffix = suffix % math.pow(10, 5)
    val nameSuffix = suffix % math.pow(10, 5)
    DistributionCentre(s"DC$codeSuffix", s"DC $nameSuffix")
  }

  def await[A](future: Future[A]): A =
    Await.result(future, 1.second)

  implicit class WSClientOps(ws: WSClient) {
    def search() =
      ws.url("http://localhost:8080/dc").get()

    def create(dc: DistributionCentre) =
      ws.url("http://localhost:8080/dc").post(Json.toJson(dc))

    def read(code: String) =
      ws.url(s"http://localhost:8080/dc/$code").get()

    def update(code: String, dc: DistributionCentre) =
      ws.url(s"http://localhost:8080/dc/$code").put(Json.toJson(dc))

    def delete(code: String) =
      ws.url(s"http://localhost:8080/dc/$code").delete()
  }

  "DC crud" should {
    "allow users to create, read, and search for DCs" in {
      WsTestClient.withClient { ws =>
        // Get a list of the existing DCs from the API (as JSON objects):
        val JsArray(initial) = await(ws.search()).json

        // Create a new DC:
        val dc = createDc.next()
        await(ws.create(dc))

        // Check we can read the new DC:
        await(ws.read(dc.code)).json mustEqual Json.toJson(dc)

        // Check the new DC is included in search results:
        await(ws.search()).json must beLike[JsValue] {
          case JsArray(items) =>
            items must containTheSameElementsAs(Json.toJson(dc) +: initial)
        }
      }
    }

    "allow users to create, update, and delete DCs" in {
      WsTestClient.withClient { ws =>
        // Get a list of the existing DCs from the API (as JSON objects):
        val JsArray(initial) = await(ws.search()).json

        // Create a new DC:
        val originalDc = createDc.next()
        val updatedDc = createDc.next()
        await(ws.create(originalDc))

        // Check we can read the original DC:
        await(ws.read(originalDc.code)).json mustEqual Json.toJson(originalDc)
        await(ws.read(updatedDc.code)).status mustEqual 404

        // Update the DC:
        await(ws.update(originalDc.code, updatedDc))

        // Check we can read the updated DC:
        await(ws.read(originalDc.code)).status mustEqual 404
        await(ws.read(updatedDc.code)).json mustEqual Json.toJson(updatedDc)

        // Delete the DC:
        await(ws.delete(updatedDc.code))

        // Check it's completely gone:
        await(ws.read(originalDc.code)).status mustEqual 404
        await(ws.read(updatedDc.code)).status mustEqual 404
      }
    }
  }
}