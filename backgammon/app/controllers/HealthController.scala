package controllers

import domain._
import play.api.mvc.{Action, Controller}
import repository.Health
import com.wordnik.swagger.annotations._
import play.api.libs.concurrent.Execution.Implicits.defaultContext

@Api(value="/health", description="/health")
trait HealthController extends Controller {
  this: Health =>
  @ApiOperation(nickname="getHealth", value="getHealth", httpMethod = "GET")
  def getHealth = Action.async { implicit request =>
    health.checkHealth.map(h => Ok(buildResponse(h)))
  }
}

class HealthControllerImpl extends SmcController with HealthController
