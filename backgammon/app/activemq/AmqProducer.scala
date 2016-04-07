package activemq

import akka.actor.Actor
import akka.camel.{CamelMessage, Oneway, Producer}
import domain.SmcConfig
import domain.activemq.AmqMessage

class AmqProducer extends Actor with Producer with Oneway {

  val queue = SmcConfig.getString("activemq.xtbroker.queue")
  def endpointUri: String = s"activemq:queue:$queue"

  override protected def transformOutgoingMessage(msg: Any) = msg match {
    case AmqMessage(body, header) =>
      new CamelMessage(body, header)
  }

}
