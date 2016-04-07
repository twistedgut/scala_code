package activemq

import activemq.health.{AmqCheck, ActivemqHealth, AmqCheckConnection}
import domain.HealthCheck
import org.specs2.specification.Scope
import play.api.libs.concurrent.Execution.Implicits.defaultContext
import play.api.test.PlaySpecification

import scala.concurrent.Future

class ActivemqHealthSpec extends PlaySpecification {

  class TestActivemq(future: Future[Any]) extends ActivemqHealth with AmqCheck with Scope {
    override def checkActivemq = future
  }
  "Amq Health " should {

    "return true when the active MQ broker is reachable" in new TestActivemq(Future(200)) {
      await(health.checkHealth).ok must beTrue
    }

    "return Not Ok when the active MQ broker is not reachable" in new TestActivemq(Future(500)) {
      await(health.checkHealth) mustEqual HealthCheck("activemq", false, "Not Ok")
    }
  }
}
