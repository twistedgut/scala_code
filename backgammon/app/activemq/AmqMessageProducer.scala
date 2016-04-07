package activemq

import akka.actor._
import domain.activemq._
import play.api.Logger
import repository.ErrorMessageException

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future
import scala.util.{Failure, Success}

case class AmqMessageProducer(dcCode: Future[String],
                              restrictionWindow: RestrictionWindow,
                              restrictions: Future[Seq[AmqChannelRestriction]],
                              actorSystem: ActorSystem) extends AmqMessageHelperMethods {

  def sendAmqMessages(): Unit = {
    val amqEnabled = amqConf.getBoolean("enabled")
    if (amqEnabled) {
      val dcRestrictions = for {
        dc <- dcCode
        res <- restrictions
      } yield (dc, res)

      dcRestrictions onComplete {
        case Success(deliveryRestrictions) => {
          generateAndSendMessages(
            deliveryRestrictions._1,
            deliveryRestrictions._2,
            actorSystem,
            restrictionWindow
          )
        }
        case Failure(e) => {
          val msg = "Unable to retrieve restrictions for AMQ message production."
          Logger.error(msg + e.printStackTrace)
          throw ErrorMessageException(msg)
        }
      }
    }
  }

}
