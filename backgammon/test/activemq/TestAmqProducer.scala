package activemq

import akka.actor.Actor
import akka.camel.{Oneway, Producer}

class TestAmqProducer extends Actor with Producer with Oneway {

  def endpointUri: String = "activemq:queue:test"

}
