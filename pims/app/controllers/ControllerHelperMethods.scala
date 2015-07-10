package controllers

import play.api.libs.json.{Json, JsValue, Reads}
import play.api.mvc.{Result, Request}
import repository.BadRequestJsonException

import scala.concurrent.Future

trait ControllerHelperMethods {

  /**
   * Attempt to parse the body of `request` as an `A`.
   * If parsing succeeds, call `func` and return its result.
   * If parsing fails, return a `BadRequest` result.
   */
  def withRequestBodyAs[A: Reads]
  (request: Request[JsValue])
  (func: A => Future[Result]): Future[Result] = {
    Json.fromJson[A](request.body).fold(
      errors => Future.failed(BadRequestJsonException(errors)),
      value  => func(value)
    )
  }

}
