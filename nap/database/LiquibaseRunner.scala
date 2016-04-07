package nap.database

import java.sql.Connection

import com.typesafe.config.ConfigFactory
import liquibase.Liquibase
import liquibase.database.DatabaseFactory
import liquibase.database.jvm.JdbcConnection
import liquibase.resource.ClassLoaderResourceAccessor
import slick.jdbc.JdbcBackend

/**
  * Created by m.esquerra on 25/01/2016.
  */
object LiquibaseRunner {

  def main(args: Array[String]): Unit = {
    println("Starting Liquibase Runner")

    val config = ConfigFactory.defaultApplication()

    if(!config.hasPath("database")) {
      sys.error("ERROR: No configuration file could be loaded or it has no \"database\" section.")
      sys.error("ERROR: Exiting now")
      return ()
    }

    val db: JdbcBackend.DatabaseDef = slick.jdbc.JdbcBackend.Database.forConfig("database")

    val s = db.createSession()
    try {
      val c = s.conn
      try {
        runLiquibase(c)
      } finally {
        c.rollback()
        c.close()
      }
    }finally {
      s.close
    }
  }

  private def runLiquibase(c: Connection) = {

    val database = DatabaseFactory.getInstance().findCorrectDatabaseImplementation(new JdbcConnection(c))

    val liquibase = new Liquibase("nap/database/updates.xml", new ClassLoaderResourceAccessor(), database)
    liquibase.update("")
  }


}
