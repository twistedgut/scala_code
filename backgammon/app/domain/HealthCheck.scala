package domain

import play.api.libs.json.Json

case class HealthCheck(name: String, ok: Boolean, description: String)

object HealthCheck {
  implicit val healthCheckFormat = Json.format[HealthCheck]
}
