package activemq.health

import domain.SmcConfig
import play.api.libs.ws.ning.NingWSClient

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

trait AmqCheckConnection extends AmqCheck {

  val amqConf = SmcConfig.getConfig("activemq.xtbroker")

  val amqHost = amqConf.getString("host")
  val amqPort = amqConf.getString("port")

  val wsClient = NingWSClient()
  val amqResponse = wsClient.url(s"http://$amqHost:$amqPort/admin/topics.jsp").get()

  def checkActivemq: Future[Int] = {
    for {
      amq <- amqResponse
    } yield amq.status
  }
}
