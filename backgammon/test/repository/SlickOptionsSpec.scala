package repository

import helpers.TestShippingOption
import org.specs2.specification.Scope
import play.api.test.PlaySpecification

class SlickOptionsSpec extends PlaySpecification {

  class TestSlickOptions extends TestDatabase with Scope {

    "search method" should {

      "return all shipping options" in new TestSlickOptions with TestShippingOption {
        // GIVEN

        // Fetch all of the current Options in the database
        val initial = await(options.search())

        // WHEN

        // Create a new shipping option
        val newOption = await(createTestShippingOption())

        // THEN

        // The search endpoint should return initial plus new Options.
        val expected = newOption +: initial
        val actual = await(options.search())

        actual must containTheSameElementsAs(expected)
      }
    }
  }
}