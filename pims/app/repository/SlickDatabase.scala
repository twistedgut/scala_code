package repository

import slick.driver.JdbcProfile

trait SlickDatabase {

  val driver: JdbcProfile
  val db: slick.jdbc.JdbcBackend.Database

}
