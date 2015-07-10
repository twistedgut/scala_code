package repository

import play.api.data.validation.ValidationError
import play.api.libs.json._
import play.api.mvc.Result
import play.api.mvc.Results._

/**
 * Standard error that can be returned by the API.
 * Various methods can produce failed Futures/DBIOActions
 * containing these errors. Errors are captured and
 * converted to Results in the Controllers.
 */
sealed abstract class StandardError(val message: String)
    extends Exception(message) {
  def errorType = getClass.getSimpleName.replaceAll("Exception", "")
  def status: Int
  def content: JsObject
  def toResult: Result = Status(status)(content)
}

object StandardError {
  def handler: PartialFunction[Throwable, Result] = {
    case exn: StandardError => exn.toResult
  }
}

/**
 * Error returned when an `item` of a specified `itemType`
 * could not be found.
 */
case class NotFoundException(itemType: String, item: String)
    extends StandardError(s"Not found: $itemType $item") {
  def status = 404
  def content = Json.obj(
    "error"    -> errorType,
    "itemType" -> itemType,
    "item"     -> item
  )
}

/**
 * Error returned when an `item` of a specified `itemType`
 * already exists.
 */
case class AlreadyExistsException(itemType: String, item: String)
    extends StandardError(s"Already exists: $itemType $item") {
  def status = 400
  def content = Json.obj(
    "error" -> errorType,
    "type"  -> itemType,
    "item"  -> item
  )
}

/**
 * Error returned when an `item` of a specified `itemType`
 * already exists.
 */
case class BadRequestJsonException(errors: Seq[(JsPath, Seq[ValidationError])])
    extends StandardError(s"Bad request JSON") {
  def status = 400
  def content = Json.obj(
    "error"      -> errorType,
    "ReadErrors" -> JsObject(errors map {
                      case (path, errs) =>
                        path.toJsonString ->
                          JsArray(errs map (e => JsString(e.message)))
                    })
  )
}

