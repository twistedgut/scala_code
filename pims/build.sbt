lazy val root = (project in file(".")).
  enablePlugins(PlayScala).

  settings(
    name := "pims",

    version := "1.0",

    scalaVersion := "2.11.6",

    libraryDependencies ++= Seq(
      "com.typesafe.slick" %% "slick" % "3.0.0",
      //"org.slf4j" % "slf4j-nop" % "1.6.4",
  	  jdbc,
      cache,
      ws,
  	  "mysql" % "mysql-connector-java" % "5.1.35",
      specs2 % Test,
  	  "com.h2database" % "h2" % "1.4.187" % Test
    )
  ).

  // Packaging (native-packager)
  enablePlugins(JavaServerAppPackaging).
  settings(Packaging.settings: _*).
  settings(
    javaOptions in Universal ++= Seq(
      "-Dconfig.file=/etc/packaging-service/application.conf"
    )
  )

resolvers += "scalaz-bintray" at "http://dl.bintray.com/scalaz/releases"
