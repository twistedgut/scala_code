package auth

object SimpleAuthImpl extends Auth {

  override def name :String = "Hardcoded Credential Checker"

  // working hardcoded creds:
  // admin = hello/secret123
  // user = hellouser/secret123

  override def check(username :String, password: String) :AuthResponse =
    password match {
      case "secret123" => username match {
        case "hello" => CRLoginOkAdmin
        case "hellouser" => CRLoginOkUser
        case _ => CRBadCredentials
      }
      case _ => CRBadCredentials
    }
}
