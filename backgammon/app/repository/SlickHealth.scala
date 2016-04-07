package repository

import domain.HealthCheck
import play.api.libs.concurrent.Execution.Implicits.defaultContext

import scala.concurrent.Future

trait SlickHealth extends Health {
  this: Database =>

  override val health = new DatabaseHealthChecker
  class DatabaseHealthChecker extends HealthChecker {

    def checkerName: String = "database"

    def checkHealth: Future[HealthCheck] =
      checkDatabase map {
        case _ =>
          HealthCheck(checkerName, true, "Ok")
      } recover {
        case throwable =>
          HealthCheck(checkerName, false, throwable.getMessage)
      }
  }
}
