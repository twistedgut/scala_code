package repository

import slick.driver.PostgresDriver

trait PostgresDatabase extends SlickDatabase with Database {

  override val profile = PostgresDriver
  override def db = PostgresDatabase.db

}

object PostgresDatabase {
  val db = slick.jdbc.JdbcBackend.Database.forConfig("database")
}