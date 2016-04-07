import com.typesafe.sbt.packager.rpm.RpmPlugin.autoImport._
import sbt.Keys._
import scala.util.Properties

name := """smcapi"""

val sharedSettings = Seq(
  version       := "0.1",
  scalaVersion  := "2.11.7"
)

val akka = "2.4.1"
val amq = "5.11.1"

lazy val root = (project in file(".")).
  enablePlugins(PlayScala).
  settings(sharedSettings: _*).
  settings(
    name                := """smcapi""",
    libraryDependencies ++= Seq(
      filters,
      ws,
      "com.typesafe.play"           %% "play-slick"                  % "1.1.0",
      "org.postgresql"              %  "postgresql"                  % "9.4-1203-jdbc42",
      "com.typesafe.play"           %% "play-slick-evolutions"       % "1.1.0",
      "pl.matisoft"                 %% "swagger-play24"              % "1.4",
      "com.netaporter"              %% "sosdb"                       % "0.1.51",
      "com.typesafe.scala-logging"  %% "scala-logging"               % "3.1.0",
      "net.logstash.logback"        %  "logstash-logback-encoder"    % "3.4",
      "com.typesafe.akka"           %% "akka-actor"                  % akka,
      "com.typesafe.akka"           %% "akka-camel"                  % akka,
      "com.typesafe.akka"           %% "akka-slf4j"                  % akka,
      "org.apache.activemq"         %  "activemq-all"                % amq,
      "org.apache.activemq"         %  "activemq-camel"              % amq,
      "com.typesafe.akka"           %% "akka-testkit"                % akka % "test",
      "com.github.tototoshi"        %% "scala-csv"                   % "1.3.0",
      specs2 % Test
    ),
    resolvers           += "scalaz-bintray" at "http://dl.bintray.com/scalaz/releases",
    resolvers           += "net-a-porter" at "http://artifactory.dave.net-a-porter.com:8081/artifactory/nap-releases-local",

    // Play provides two styles of routers, one expects its actions to be injected, the
    // other, legacy style, accesses its actions statically.
    routesGenerator := InjectedRoutesGenerator

  )
  .settings(
    rpmVendor  in Rpm := "Net-A-Porter",
    rpmLicense in Rpm := Some("Copyright (c) Net-A-Porter"),
    rpmRelease in Rpm := Properties.envOrElse("BUILD_NUMBER", "0")
  )

scalacOptions in ThisBuild ++= Seq("-unchecked", "-deprecation", "-feature")

addCommandAlias("package", "rpm:packageBin")

// Remove the dev conf files from the RPM (puppet will provide them)

mappings in Universal := {
  (mappings in Universal).value filter {
    case (file, name) => !(!name.equals("conf/application.ini") && name.startsWith("conf/"))
  }
}

// Remove the symlink that points to the directory where the above files were to be
// installed (and is no longer needed, but clashed with a directory puppet creates)
linuxPackageSymlinks := {
  (linuxPackageSymlinks).value filter {
    case link => !link.link.equals("/etc/smc")
  }
}

