package integration

import controllers.Formats
import domain._
import test.PimsTest

import org.specs2.mutable.Specification
import play.api.libs.json._

class QuantitySpec extends Specification with Formats with PimsTest with IntegrationTest {

  def createBox(dcCode: String) = Counter { suffix =>
    Box(s"box-code-$suffix", s"box-name-$suffix", dcCode)
  }

  val createDcData = Counter { suffix =>
    DistributionCentre(s"dc-code-$suffix", s"dc-name-$suffix")
  }

  // quantity json: {"name":"Box 1","code":"box1","quantity":0}

  "The /quantity endpoint" should {
    "allow users to increment and decrement the quantity for boxes" in new WithApp {
      // Set up quantity tests by creating a DC and a box
      val dc   = createDcData.next()
      val box  = createBox(dc.code).next()
      await(request("/dc").post(Json.toJson(dc))).status must equalTo (200)
      await(request("/box").post(Json.toJson(box))).status must equalTo (200)

      // Ensure that the quantity for the new box is zero:
      val JsArray(initial) = await(request("/business").get()).json

      // Create a new business:
      val originalBus = createBusiness.next()
      await(request("/business").post(Json.toJson(originalBus))).status must equalTo (200)

      // Check we can read the original business:
      await(request(s"/business/${originalBus.code}").get()).json mustEqual Json.toJson(originalBus)

      // Check the new business is included in search results:
      await(request("/business").get()).json must beLike[JsValue] {
        case JsArray(items) =>
          items must containTheSameElementsAs(Json.toJson(originalBus) +: initial)
      }
    }

    "allow users to create, update, and delete businesses" in new WithApp {
      // Create a new business:
      val originalBus = createBusiness.next()
      await(request("/business").post(Json.toJson(originalBus))).status must equalTo (200)

      // Create a new business object and make sure it is not available via a read:
      val updatedBus = createBusiness.next()
      await(request(s"/business/${updatedBus.code}").get()).status mustEqual 404

      // Update the original business with the new updated one:
      await(request(s"/business/${originalBus.code}").put(Json.toJson(updatedBus))).status must equalTo (200)

      // Check we can read the updated business, but not the original one:
      await(request(s"/business/${originalBus.code}").get()).status mustEqual 404
      await(request(s"/business/${updatedBus.code}").get()).json mustEqual Json.toJson(updatedBus)

      // Delete the business:
      await(request(s"/business/${updatedBus.code}").delete())

      // Check it's completely gone:
      await(request(s"/business/${originalBus.code}").get()).status mustEqual 404
      await(request(s"/business/${updatedBus.code}").get()).status mustEqual 404
    }
  }
}
