package domain

trait Formats {
  import play.api.libs.json._
  import play.api.libs.json.Reads._
  import play.api.libs.functional.syntax._

  implicit val indexFormat = new Writes[Index] {
    def writes(index: Index) = Json.obj(
      "service" -> index.service
    )
  }

  implicit val boxFormat : Reads[Box] = (
    (JsPath \ "code").read[String] and
    (JsPath \ "name").read[String] and
    (JsPath \ "business_code").read[String]
  )(Box.apply _)

}
