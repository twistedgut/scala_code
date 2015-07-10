package repository

import org.specs2.mutable.Specification
import org.specs2.specification.Scope
import domain.DistributionCentre
import scala.concurrent.{Await, Future, ExecutionContext}
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration._

class SlickDistributionCentresSpec extends Specification {

  trait TestModule extends SlickDistributionCentres
    with MySqlDatabase
    with SlickTables
    with Scope

  val createDc = Counter { suffix =>
    // Codes and names are limited in length,
    // so we can't have gigantic suffixes:
    val codeSuffix = suffix % math.pow(10, 5)
    val nameSuffix = suffix % math.pow(10, 5)
    DistributionCentre(s"DC$codeSuffix", s"DC $nameSuffix")
  }

  def await[A](future: Future[A]): A =
    Await.result(future, 3.seconds)

  def beUnit = beEqualTo(())

  "search method" should {
    "return all dcs" in new TestModule {
      // Fetch all the DCs currently in the database:
      val initial = await(distributionCentres.search())

      // Insert a new DC:
      val newDc = createDc.next()
      await(distributionCentres.create(newDc))

      // The search endpoint should now return `initial`
      // plus the newly inserted DC:
      val expected = (newDc +: initial)
      val actual = await(distributionCentres.search())

      actual must containTheSameElementsAs(expected)
    }
  }

  "read method" should {
    "return a dc" in new TestModule {
      val newDc = createDc.next()
      await(distributionCentres.create(newDc))
      await(distributionCentres.read(newDc.code)) mustEqual Some(newDc)
    }

    "return None if the dc is not found" in new TestModule {
      val newDc = createDc.next()
      await(distributionCentres.read(newDc.code)) mustEqual None
    }
  }

  "create method" should {
    "create a dc" in new TestModule {
      val newDc = createDc.next()

      // The create endpoint should succeed:
      await(distributionCentres.create(newDc)) mustEqual newDc

      // The new DC must be in the database:
      await(distributionCentres.read(newDc.code)) mustEqual Some(newDc)
    }

    "fail if the dc exists" in new TestModule {
      val newDc = createDc.next()

      // Insert the DC once:
      await(distributionCentres.create(newDc))

      // Insert it again... the create endpoint shoud fail:
      await(distributionCentres.create(newDc)) must throwAn[AlreadyExistsException]

      // However, the new DC should still be in the database:
      await(distributionCentres.read(newDc.code)) mustEqual Some(newDc)
    }
  }

  "update method" should {
    "update a dc" in new TestModule {
      // Create a DC:
      val originalDc = createDc.next()
      await(distributionCentres.create(originalDc))

      // Update the DC -- set all fields to new values.
      // The update endpoint should return a success:
      val updatedDc = createDc.next()
      await(distributionCentres.update(originalDc.code, updatedDc)) mustEqual updatedDc

      // The DC's code has changed.
      // The read method should return
      // None for the old code and Some for the new code:
      await(distributionCentres.read(originalDc.code)) mustEqual None
      await(distributionCentres.read(updatedDc.code)) mustEqual Some(updatedDc)
    }

    "fail if the dc is not found" in new TestModule {
      val originalDc = createDc.next()
      val updatedDc = createDc.next()

      // Try to update a DC that isn't in the database.
      // The method should fail:
      await(distributionCentres.update(originalDc.code, updatedDc)) must throwA[NotFoundException]

      // Neither the original nor the updated DC code
      // should be in the datbase:
      await(distributionCentres.read(originalDc.code)) mustEqual None
      await(distributionCentres.read(updatedDc.code)) mustEqual None
    }
  }

  "delete method" should {
    "delete a dc" in new TestModule {
      // Create a DC:
      val newDc = createDc.next()
      await(distributionCentres.create(newDc))

      // Verify it's in the database:
      await(distributionCentres.read(newDc.code)) mustEqual Some(newDc)

      // The delete method should return success:
      await(distributionCentres.delete(newDc.code)) must beUnit

      // The DC should be deleted:
      await(distributionCentres.read(newDc.code)) mustEqual None
    }

    "succeed if the dc is not found" in new TestModule {
      // Create a DC:
      val newDc = createDc.next()

      // Verify the DC isn't in the database:
      await(distributionCentres.read(newDc.code)) mustEqual None

      // The delete method should succeed anyway:
      await(distributionCentres.delete(newDc.code)) must beUnit

      // The DC should still not be in the database:
      await(distributionCentres.read(newDc.code)) mustEqual None
    }

    "not delete other dcs" in new TestModule {
      // Create two new DCs:
      val newDc1 = createDc.next()
      val newDc2 = createDc.next()

      await(distributionCentres.create(newDc1))
      await(distributionCentres.create(newDc2))

      // Delete one of the two new DCs:
      await(distributionCentres.delete(newDc1.code)) mustEqual (())

      // Only one DC should remain in the database:
      await(distributionCentres.read(newDc1.code)) mustEqual None
      await(distributionCentres.read(newDc2.code)) mustEqual Some(newDc2)
    }
  }
}
