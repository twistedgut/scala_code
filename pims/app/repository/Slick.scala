package repository

/**
 * A convenience trait to allow access to Slick database logic
 */
trait Slick
  extends MySqlDatabase
  with SlickTables
  with SlickQuantities
  with SlickDistributionCentres
  with SlickBoxes
