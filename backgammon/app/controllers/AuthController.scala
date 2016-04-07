package controllers

import auth._
import domain._
import domain.APIResponse._
import domain.auth._
import com.wordnik.swagger.annotations._
import play.api.mvc._

trait AuthController extends Controller {

  @ApiOperation(nickname= "login_info", value="login_info", httpMethod = "GET")
  def login_info() = Action { implicit request =>
    Ok(buildResponse(LoginInfo(
      username = request.session.get("username").getOrElse(""),
      is_logged_in = !request.session.isEmpty,
      is_admin = (request.session.get("is_admin").getOrElse("false") == "true")
    )))
  }

  @ApiOperation(nickname= "login", value="login", httpMethod = "POST")
  @ApiImplicitParams(Array(new ApiImplicitParam(dataType = "domain.auth.LoginDetails", paramType = "body")))
  def login() = Action { req =>
    req.bodyAs[LoginDetails] match {
      case None => BadRequest("No username or password supplied")
      case Some(loginDetails) => Auth.check(loginDetails.username, loginDetails.password) match {
        case x: CRLoginOk => Ok(APIResponse(
          uri = req.path,
          responseBody = None,
          success = true,
          error_msg = ""
        )).withSession(
          "username" -> loginDetails.username,
          "is_admin" -> x.isAdmin.toString
        )
        case f :CRFailedLogin => Unauthorized(APIResponse(
          uri = req.path,
          responseBody = None,
          success = false,
          error_msg = f.description
        ))
        case authResponse => InternalServerError(APIResponse(
            uri = req.path,
            responseBody = None,
            success = false,
            error_msg = authResponse.description
          ))
      }
    }

  }

  @ApiOperation(value="logout", httpMethod = "POST")
  def logout() = Action(parse.raw) { req =>
    Ok(APIResponse(
      uri = req.path,
      responseBody = None,
      success = true,
      error_msg = ""
    )).withNewSession
  }

}
@Api(value="/auth")
class AuthControllerImpl extends SmcController with AuthController
