package activemq

import akka.actor.ActorSystem

trait AmqAkkaActor {
  def amqActorSystem = ActorSystem("WebappUpdate")
}
