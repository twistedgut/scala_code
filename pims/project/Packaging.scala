import sbt.Keys._
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

  // Remove the dev conf files from the RPM (puppet will provide them)
  mappings in Universal := {
      (mappings in Universal).value filter {
      case (file, name) =>  ! name.startsWith("conf/")
    }
  }

  // Remove the symlink that points to the directory where the above files were to be
  // installed (and is no longer needed, but clashed with a directory puppet creates)
  linuxPackageSymlinks := {
    (linuxPackageSymlinks).value filter {
      case link =>  ! link.link.equals("/etc/pims")
    }
  }
}
