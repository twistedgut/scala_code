package auth

import java.util.Hashtable
import javax.naming.Context
import javax.naming.directory.{SearchResult, SearchControls}
import javax.naming.ldap.InitialLdapContext

import com.typesafe.scalalogging.StrictLogging
import domain.SmcConfig

object LDAPAuthImpl extends Auth
                       with StrictLogging {

  private val ldapDomains = SmcConfig.getStringList("ldap.domains")
  override def name :String = "Net-a-Porter.com LDAP"

  override def check(username :String, password :String) :AuthResponse = {
    try {
      doCheck(username, password)
    } catch {
      case e: Throwable => {
        println(s"Exception: $e");
        CRUnknownException
      }
    }
  }

  def doCheck(username: String, password: String) :AuthResponse = {
    val preauthedContext = buildConnectionContext(
      SmcConfig.getString("ldap.user"),
      SmcConfig.getString("ldap.password")
    )

    val a = getUser(preauthedContext, username).flatMap((user: SearchResult) => getFullyQualifiedUsername(username, user))
    try {
      val responseOpt = for {
        initialUser            <- getUser(preauthedContext, username)
        fullyQualifiedUsername <- getFullyQualifiedUsername(username, initialUser)
        userAuthContext        =  buildConnectionContext(fullyQualifiedUsername, password)
        user                   <- getUser(userAuthContext, username)
      } yield {
          preauthedContext.close()
          userAuthContext.close()
          if (hasSmcAdmin(user))
            CRLoginOkAdmin

          else if (hasSmcUser(user))
            CRLoginOkUser
          else
            CRNoLDAPRole
      }


      responseOpt.getOrElse(CRBadCredentials)

    } catch {
      case e :Throwable => {
        CRBadCredentials
      }
    }

  }

  def getUser(ctx: InitialLdapContext, username: String) :Option[SearchResult] = {
    val constraints = new SearchControls()
    constraints.setReturningAttributes(Array("cn","memberOf", "l", "displayName", "sAMAccountName"))
    constraints.setSearchScope(SearchControls.SUBTREE_SCOPE)

    val result = ctx.search(
      SmcConfig.getString("ldap.baseDn"),
      s"(sAMAccountName=$username)",
      constraints
    )

    while (result.hasMore()) {
      val r: SearchResult = result.next()
      return Some(r)
    }

    return None

  }

  def getFullyQualifiedUsername(username :String, user :SearchResult): Option[String] = {
    getUserDomain(user).map{domain =>
      val r = s"$domain\\$username"
      logger    info    s"User trying to connect as '$r'"
      r
    }
  }

  def getUserDomain(user: SearchResult) : Option[String] = {
    user.getNameInNamespace.split("\\,").flatMap{entry =>
      entry.split("\\=").toList match {
        case key :: value :: Nil =>
          if (ldapDomains.contains(value)) Seq(key -> value)
          else Seq.empty
        case _ => Seq.empty
      }
    }.toMap.get("DC")
  }
  def hasSmcUser(user :SearchResult) :Boolean = {
    hasLdapGroup(user, SmcConfig.getString("ldap.smcUserLDAPGroupAttribute"), ldapDomains)
  }
  def hasSmcAdmin(user :SearchResult) :Boolean = {
    hasLdapGroup(user, SmcConfig.getString("ldap.smcAdminLDAPGroupAttribute"), ldapDomains)
  }
  private def hasLdapGroup(user :SearchResult, group :String, dcs: List[String]) :Boolean = {
    dcs.exists { dc =>
      val groupWithDc = group.replaceAllLiterally(",DC=,", s",DC=$dc,")
      user.getAttributes.get("memberOf").contains(groupWithDc)
    }
  }

  def buildConnectionContext(username :String, password :String) :InitialLdapContext = {
    val env = new Hashtable[String, String]()
    env.put(Context.PROVIDER_URL, SmcConfig.getString("ldap.url"))
    env.put(Context.SECURITY_AUTHENTICATION, SmcConfig.getString("ldap.security_authentication"))
    env.put(Context.SECURITY_PRINCIPAL, username)
    env.put(Context.SECURITY_CREDENTIALS, password)
    env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory")
    new InitialLdapContext(env, null)
  }

}
