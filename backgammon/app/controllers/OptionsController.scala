package controllers

import com.wordnik.swagger.annotations.{Api, ApiOperation}
import domain.{ShippingOptionSearchResult, _}
import domain.auth.{Authed, DefaultAuthManagerImplementation, HasAuthManager, User}
import play.api.mvc.{Action, Controller}
import repository._

import scala.concurrent.ExecutionContext.Implicits.global

trait OptionsController extends Controller
                           with HasAuthManager {
  this: Options =>

  @ApiOperation(
    nickname          = "searchShippingOptions",
    value             = "Returns all shipping options",
    httpMethod        = "GET",
    response          = classOf[ShippingOptionSearchResult],
    responseContainer = "List"
  )
  def searchShippingOptions() = Authed(User) {
    Action.async { implicit request =>
      options.search().map(options => Ok(buildResponse(options)))
    }
  }
}

@Api(value = "/shipping/options")
class OptionsControllerImpl extends SmcController
                               with OptionsController
                               with DefaultAuthManagerImplementation
