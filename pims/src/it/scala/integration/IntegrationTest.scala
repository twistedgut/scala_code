package integration

import play.api.Application
import play.api.test._
import play.api.libs.ws.{WS, WSRequest}

import scala.concurrent.{Future, Await}
import scala.concurrent.duration._

trait IntegrationTest extends PlaySpecification {

  def request(path: String)(implicit app: Application): WSRequest = WS.url(IntegrationTestConfig.url + path)

  def defaultTimeout = 3 seconds

  def await[A](future: Future[A], timeout: Duration = defaultTimeout) = Await.result(future, timeout)

}

abstract class WithApp extends WithApplication
