package activemq

import akka.actor._
import akka.camel.CamelExtension
import domain.SmcConfig
import domain.activemq._
import org.apache.activemq.camel.component.ActiveMQComponent
import play.api.Logger
import play.api.libs.json.Json

trait AmqMessageHelperMethods {

  val amqConf = SmcConfig.getConfig("activemq.xtbroker")

  def getActorRef(actorSystem: ActorSystem): ActorRef = {
    val amqHost = amqConf.getString("host")
    val amqPort = amqConf.getString("port")
    val amqUrl = s"tcp://$amqHost:$amqPort"

    // Initialise the Akka Camel actor with AMQ URL
    val system = CamelExtension(actorSystem)
    system.context.addComponent("activemq", ActiveMQComponent.activeMQComponent(amqUrl))
    actorSystem.actorOf(Props[AmqProducer])
  }

  def createAmqMessage(dc: String, channel: String, seqRestrictions: Seq[AmqDeliveryRestriction], window: RestrictionWindow): AmqMessage = {
    val xtConf = SmcConfig.getConfig(s"xt_channel_idents.$dc.$channel")
    val channelId = xtConf.getString("id")
    val channelName = xtConf.getString("name")
    AmqMessage(
      Json.toJson(
        RestrictionMessage(
          channelName,
          seqRestrictions,
          window
        )
      ).toString,
      Map("channel_name" -> channelName,
        "channel_id" -> channelId,
        "content_type" -> "json",
        "producer_timestamp" -> System.currentTimeMillis.toString,
        "JMSType" -> "ShippingRestrictedDays")
    )
  }

  def sendAmqMessage(aRef: ActorRef, msg: AmqMessage): Boolean = {
    // Attempt to send the message to the AMQ broker
    try {
      aRef ! msg
      true
    }
    catch {
      case e: Throwable => Logger.error("Error writing message to AMQ broker. " + e.printStackTrace)
        false
    }
  }

  def generateAndSendMessages(dc: String, res: Seq[AmqChannelRestriction], acs: ActorSystem, window: RestrictionWindow ) = {
    val amqProducer = getActorRef(acs)
    val allChannelRestrictions = res
    for (channel <- List("NAP", "TON", "MRP")) {
      val channelRestrictions = allChannelRestrictions
        .filter(_.business_code == channel)
        .map(_.deliveryRestriction)
      val msg = createAmqMessage(dc, channel, channelRestrictions, window)
      Logger.info(msg.toString)
      sendAmqMessage(amqProducer, msg)
    }
  }

}
