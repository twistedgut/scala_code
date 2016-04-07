package activemq.health

import domain.HealthCheck
import repository.Health

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

trait ActivemqHealth extends Health {
  this: AmqCheck =>

  override val health = new ActivemqChecker

  class ActivemqChecker extends HealthChecker {

    def checkerName: String = "activemq"

    override def checkHealth: Future[HealthCheck] = {
      checkActivemq map {
        case 200 => HealthCheck(checkerName, true, "Ok")
        case _   => HealthCheck(checkerName, false, "Not Ok")
      }
    }
  }
}
