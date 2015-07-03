import sbt._
import com.typesafe.sbt.packager.Keys._
import com.typesafe.sbt.SbtNativePackager._
import scala.util.Properties

object Packaging {

  val settings: Seq[Setting[_]] = Seq(
    rpmVendor in Rpm := "Net-A-Porter",
    rpmLicense in Rpm := Some("Copyright (c) Net-A-Porter"),
    rpmRelease in Rpm := Properties.envOrElse("BUILD_NUMBER", "0")
  )
}
