package repository

import domain.HealthCheck
import org.specs2.specification.Scope
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import play.api.test.PlaySpecification

import scala.concurrent.Future

class SlickHealthSpec extends PlaySpecification {

  class TestHealth(future: Future[Any]) extends SlickHealth with Database with Scope {

    override def checkDatabase = future

  }

  "Slick Health" should {

    "return a positive connection when the database is up" in new TestHealth(Future(())) {
      await(health.checkHealth).ok must beTrue
    }

    "return a negative connection when the database is down" in new TestHealth(Future.failed(new Exception("Not OK"))) {
      await(health.checkHealth) mustEqual HealthCheck("database", false, "Not OK")
    }
  }
}
