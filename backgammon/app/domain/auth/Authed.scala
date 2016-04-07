package domain.auth

import domain.APIResponse
import play.api.mvc.Results._
import play.api.mvc._

import scala.concurrent.Future

sealed trait Role
case object User extends Role
case object Admin extends Role

trait AuthManager {
  def isAuthorised[A](request: Request[A], roles: Role*): Boolean
}

trait HasAuthManager {
  implicit val authManager:AuthManager
}

trait DefaultAuthManagerImplementation extends HasAuthManager {
  implicit val authManager :AuthManager = new AuthManager {
    override def isAuthorised[A](request: Request[A], roles: Role*): Boolean =
      ((isUser(request) && roles.contains(User)) || (isAdmin(request) && roles.contains(Admin)))

    private def isUser[A](request: Request[A]) : Boolean =
      !request.session.isEmpty

    private def isAdmin[A](request: Request[A]) :Boolean =
      !request.session.isEmpty && request.session.get("is_admin").getOrElse("false") == "true"
  }
}

case class Authed[A](roles: Role*)(action: Action[A])(implicit authManger: AuthManager) extends Action[A] {

  def apply(request: Request[A]): Future[Result] = {

    if (authManger.isAuthorised(request, roles: _*))
      action(request)
    else
      unauthorized(request)
  }

  private def unauthorized(request: Request[A]) = Future.successful(Unauthorized(
    APIResponse(
        uri = request.path,
        responseBody = None,
        success = false,
        error_msg = "Not Logged In"
    )))

  lazy val parser = action.parser
}
