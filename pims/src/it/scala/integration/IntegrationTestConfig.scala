package integration

import java.net.URL

object IntegrationTestConfig {
  val url = new URL(configString("TEST_URL"))

  private def configString(key: String) =
  // Try Java system properties
  // (these can be set with the command line switch -Dname=val)
    Option(System.getProperty(key)) orElse
      // Try environment variables
      Option(System.getenv(key)) getOrElse
      // Can't find the variable -- fail!
      sys.error(s"Missing system property or envirionment variable: $key")

  private def configInt(key: String) =
    try {
      configString(key).toInt
    } catch {
      case exn: NumberFormatException =>
        sys.error(s"System property or environment variable must be an integer: $key")
    }
}
