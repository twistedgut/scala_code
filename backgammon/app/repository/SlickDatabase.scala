package repository

import slick.driver.JdbcProfile

import scala.concurrent.Future

trait SlickDatabase extends Database {

  val profile: JdbcProfile
  def db: slick.jdbc.JdbcBackend.Database

  def checkDatabase: Future[Any] = {
    import profile.api._

    db.run(sql"SELECT 1;".as[String])
  }
}

