package controllers

import domain._
import repository._

import org.specs2.mock.Mockito
import org.specs2.mutable.Specification
import org.specs2.specification.Scope
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import play.api.libs.json._
import play.api.mvc.{Result, Results}
import play.api.test.{PlaySpecification, FakeRequest}
import scala.concurrent.duration._
import scala.concurrent.{Await, Future, ExecutionContext}

class DistributionCentreControllerSpec extends PlaySpecification with Mockito {

  trait TestModule extends DistributionCentreController
    with DistributionCentres
    with Formats
    with Scope {
    val distributionCentres = mock[DistributionCentreRepository]
  }

  val createDc = Counter { suffix =>
    DistributionCentre(s"DC$suffix", s"DC $suffix")
  }

  def emptyRequest =
    FakeRequest()

  def jsonRequest[A: Writes](value: A) =
    FakeRequest().withBody(Json.toJson(value))

  "search method" should {
    "return DCs as json" in new TestModule {
      // Mock out the database:
      val dc1 = createDc.next()
      val dc2 = createDc.next()
      distributionCentres.search() returns Future(Seq(dc1, dc2))

      // Check the endpoint returns a 200:
      val result = search().apply(emptyRequest)
      status(result) mustEqual 200
      contentAsJson(result) mustEqual Json.toJson(Seq(dc1, dc2))
    }
  }

  "read method" should {
    "return a 200 if found" in new TestModule {
      // Mock out the database:
      val dc = createDc.next()
      distributionCentres.read(dc.code) returns Future(Some(dc))

      // Check the endpoint returns a 200:
      val result = read(dc.code).apply(emptyRequest)
      status(result) mustEqual 200
      contentAsJson(result) mustEqual Json.toJson(dc)
    }

    "return a 404 if not found" in new TestModule {
      // Mock out the database:
      val dc = createDc.next()
      distributionCentres.read(dc.code) returns Future(None)

      // Check the endpoint returns a 404:
      val result = read(dc.code).apply(emptyRequest)
      status(result) must throwA[NotFoundException]
    }
  }

  "create method" should {
    "create a DC" in new TestModule {
      // Mock out the database:
      val dc = createDc.next()
      distributionCentres.create(dc) returns Future(dc)

      // Check the endpoint returns a 200:
      val result = create().apply(jsonRequest(dc))
      status(result) mustEqual 200
      contentAsString(result) mustEqual ""
    }

    "fail if the DC exists" in new TestModule {
      // Mock out the database:
      val dc = createDc.next()
      distributionCentres.create(dc) returns Future.failed(AlreadyExistsException("DC", dc.code))

      // Check the endpoint returns a 400:
      await(create().apply(jsonRequest(dc))) must throwA[AlreadyExistsException]
    }
  }

  "update method" should {
    "return a 200 if DC exists" in new TestModule {
      // Mock out the database:
      val code = "SOME_DC"
      val dc = createDc.next()
      distributionCentres.update(code, dc) returns Future(dc)

      // Check the endpoint returns a 200:
      val result: Future[Result] = update(code).apply(jsonRequest(dc))
      status(result) mustEqual 200
      contentAsString(result) mustEqual ""
    }

    "return a 404 if DC doesn't exist" in new TestModule {
     // Mock out the database:
      val code = "SOME_DC"
      val dc = createDc.next()
      distributionCentres.update(code, dc) returns Future.failed(NotFoundException("DC", code))

      // Check the endpoint returns a 404:
      await(update(code).apply(jsonRequest(dc))) must throwA[NotFoundException]
    }
  }

  "delete method" should {
    "return a 200" in new TestModule {
       // Mock out the database:
      val code = "SOME_DC"
      distributionCentres.delete(code) returns Future(())

      // Check the endpoint returns a 200:
      val result: Future[Result] = delete(code).apply(emptyRequest)
      status(result) mustEqual 200
      contentAsString(result) mustEqual ""
   }
  }

}