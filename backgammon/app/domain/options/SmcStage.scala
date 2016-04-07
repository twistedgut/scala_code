package domain.options

import play.api.libs.json.Json

case class SmcStage(
    name:          String,
    code:          String,
    ranking:       Int
    )

object SmcStage {
  implicit val format = Json.format[SmcStage]
}

