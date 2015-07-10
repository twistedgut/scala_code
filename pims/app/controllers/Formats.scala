package controllers

import domain._
import play.api.libs.json._
import play.api.libs.json.Reads._
import play.api.libs.functional.syntax._

trait Formats {
  implicit val indexFormat = new Writes[Index] {
    def writes(index: Index) = Json.obj(
      "service" -> index.service
    )
  }

  implicit val boxFormat : Reads[Box] = (
    (JsPath \ "code").read[String] and
    (JsPath \ "name").read[String] and
    (JsPath \ "dc_code").read[String]
  )(Box.apply _)

  implicit val distributionCentreFormat = Json.format[DistributionCentre]

  implicit val boxQuantityFormat = Json.format[BoxQuantity]

  implicit val updateQuantityFormat = Json.format[UpdateQuantity]

}
