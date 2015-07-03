package repository

import slick.driver.MySQLDriver

trait MySqlDatabase extends SlickDatabase {

  override val driver = MySQLDriver
  override val db = slick.jdbc.JdbcBackend.Database.forConfig("database")

}
