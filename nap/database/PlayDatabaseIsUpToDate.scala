package nap.database

import com.google.inject.Inject
import com.typesafe.scalalogging.LazyLogging
import play.api.{Play, Application}
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future
import com.google.inject.AbstractModule
import DatabaseChecker._



class PlayDatabaseIsUpToDate        extends LazyLogging
{


  if   (isTheSoftwareUpToDateWithTheDatabase)  println("DATABASE UP TO DATE")
  else                                         Stop()


}

class PlayDatabaseIsUpToDateModule extends AbstractModule {

  def configure() = {
      bind(classOf[PlayDatabaseIsUpToDate]).asEagerSingleton
  }

}





class PlayDatabaseIsUpToDateOrOnePatchBehind        extends LazyLogging
{


  if   (isTheSoftwareUpToDateWithTheDatabase)  println("DATABASE UP TO DATE")
  else                                         Stop()


}

class PlayDatabaseIsUpToDateOrOnePatchBehindModule extends AbstractModule {

  def configure() = {
    bind(classOf[PlayDatabaseIsUpToDate]).asEagerSingleton
  }

}





/**
  * Stops the world. Makes sure the play app is terminated cleanly.
  */
object Stop extends LazyLogging {
  def apply() = {
    Future{
      Thread.sleep(200)
      logError("FATAL ERROR: The Database Schema is not up to date. Have Liquibase properly been run?")
      logError("FATAL ERROR: Stopping Play NOW.")
      sys.exit(0)
    }
  }

  private def logError(msg: String) = {
    System.err println msg
    logger     error   msg
  }
}
