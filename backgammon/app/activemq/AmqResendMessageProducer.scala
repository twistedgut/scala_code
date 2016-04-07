package activemq

import akka.actor._
import domain.activemq._

case class AmqResendMessageProducer(dcCode: String,
                              restrictionWindow: RestrictionWindow,
                              restrictions: Seq[AmqChannelRestriction],
                              actorSystem: ActorSystem) extends AmqMessageHelperMethods {

  def sendAmqMessages(): Unit = {
    val amqEnabled = amqConf.getBoolean("enabled")
    if (amqEnabled) {
      generateAndSendMessages(
        dcCode,
        restrictions,
        actorSystem,
        restrictionWindow
      )
    }
  }
}
