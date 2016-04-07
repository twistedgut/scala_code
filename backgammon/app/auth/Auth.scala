package auth

import domain.SmcConfig
import com.typesafe.scalalogging.StrictLogging

sealed abstract class AuthResponse(val description :String)

// results in 200 OK HTTP status code
sealed abstract class CRLoginOk(val isAdmin: Boolean) extends AuthResponse("success")
case object CRLoginOkUser extends CRLoginOk(false)                         // SUCCESS - User is Admin
case object CRLoginOkAdmin extends CRLoginOk(true)                         // SUCCESS - User is a regular user

// results in 401 Unauthorised HTTP status code
sealed abstract class CRFailedLogin(val reason: String) extends AuthResponse(reason)
case object CRBadCredentials extends CRFailedLogin("Bad Credentials")      // FAIL - Bad Username or Password
case object CRUserNotFound extends CRFailedLogin("User not found")         // FAIL - User not found in LDAP
case object CRNoLDAPRole extends CRFailedLogin("No LDAP Role")             // FAIL - Missing smc_user or smc_admin LDAP role
case object CRNoDomainAttr extends CRFailedLogin("No Domain Attribute")    // FAIL - No \\LONDON or \\NewYork domain

// results in 500 Internal Server Error HTTP status code.
case object CRUnknownException extends AuthResponse("Uncaught exception")  // FAIL - All other cases.

trait Auth {
  def name :String
  def check(username :String, password :String) :AuthResponse
}

object Auth extends StrictLogging {
  def check(username :String, password :String) :AuthResponse = {

    //choose appropriate authorisation mechanism.
    val authChecker :Auth = SmcConfig.getString("auth.method") match {
      case "ldap" => LDAPAuthImpl
      case _ => SimpleAuthImpl
    }

    val ar: AuthResponse = authChecker.check(username, password)
    logger info s"Attempt made to login with user '$username' resulted in: ${ar.description}"
    ar
  }

}
