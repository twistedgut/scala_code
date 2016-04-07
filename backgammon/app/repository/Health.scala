package repository

import domain.HealthCheck

import scala.concurrent.Future

trait Health {
  val health: HealthChecker

  trait HealthChecker {
    def checkerName : String
    def checkHealth : Future[HealthCheck]
  }
}
