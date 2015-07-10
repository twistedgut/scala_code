lazy val root = (project in file(".")).
  enablePlugins(PlayScala).

  settings(
    name := "pims",

    version := "1.0",

    scalaVersion := "2.11.6",

    libraryDependencies ++= Seq(
      "com.typesafe.slick" %% "slick" % "3.0.0",
      "org.slf4j" % "slf4j-nop" % "1.6.4",
  	  jdbc,
      cache,
      ws,
      specs2 % "test, it",
  	  "mysql" % "mysql-connector-java" % "5.1.35"
    )
  ).

  // Testing
  configs(IntegrationTest).
  settings(Defaults.itSettings: _*).
  settings(Testing.settings: _*).

  // Packaging (native-packager)
  enablePlugins(JavaServerAppPackaging).
  settings(Packaging.settings: _*)

resolvers += "scalaz-bintray" at "http://dl.bintray.com/scalaz/releases"

play.PlayImport.PlayKeys.playDefaultPort := 8080
