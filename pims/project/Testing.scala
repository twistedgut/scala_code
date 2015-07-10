import sbt.Keys._
import sbt._

object Testing {

  val settings: Seq[Setting[_]] = Seq(
    parallelExecution in Test := false,
    parallelExecution in IntegrationTest := false,
    fork in Test := true,
    fork in IntegrationTest := true,
    javaOptions in Test += "-Dconfig.resource=test.conf"
  )

}
