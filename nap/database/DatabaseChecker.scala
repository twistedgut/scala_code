package nap.database

import scala.concurrent.{Await, Future}

/**
  * Created by m.esquerra on 26/01/2016.
  */
object DatabaseChecker {

  def isTheSoftwareUpToDateWithTheDatabase: Boolean = {

    import slick.driver.PostgresDriver.api._
    import scala.concurrent.duration._

    val db = slick.jdbc.JdbcBackend.Database.forConfig("database")
    val patchesInTheDB =
      Await.result(
        db.run{
          sql"""
                SELECT DISTINCT filename FROM databasechangelog
          """.as[String]
        }, 1.second
      )

    val patchesInTheSoftware: List[String] = LiquibaseVersion.patches

    patchesInTheSoftware forall patchesInTheDB.contains
  }

  def isTheSoftwareTheSameVersionOrOnePatchBehindTheDatabase: Boolean = {

    import slick.driver.PostgresDriver.api._
    import scala.concurrent.duration._

    val db = slick.jdbc.JdbcBackend.Database.forConfig("database")
    val patchesInTheDB =
      Await.result(
        db.run{
          sql"""
                SELECT DISTINCT filename FROM databasechangelog
          """.as[String]
        }, 1.second
      )

    val patchesInTheSoftware: List[String] = LiquibaseVersion.patches
    val delta = patchesInTheSoftware.length - patchesInTheDB.length

    delta <= 1 && delta >= 0 && (patchesInTheDB forall patchesInTheSoftware.contains)
  }

}

object DatabaseCheckerRunner extends App {

  if (DatabaseChecker.isTheSoftwareUpToDateWithTheDatabase) {
    println(true)
    sys.exit(0)
  }
  else {
    println(false)
    sys.exit(1)
  }

}
