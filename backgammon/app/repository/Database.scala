package repository

import scala.concurrent.Future

trait Database {

  def checkDatabase: Future[Any]

}