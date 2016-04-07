package activemq.health

import scala.concurrent.Future

trait AmqCheck {

  def checkActivemq: Future[Any]

}
