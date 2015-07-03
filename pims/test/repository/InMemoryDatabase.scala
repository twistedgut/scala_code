package repository


trait InMemoryDatabase extends SlickDatabase {
  
  override val driver = slick.driver.H2Driver
  override val db = slick.jdbc.JdbcBackend.Database.forConfig("testDatabase")

}