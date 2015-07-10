package test

import scala.concurrent.{Await, Future}
import scala.concurrent.duration._

trait PimsTest {
  def defaultTimeout = 3 seconds

  /**
   * Given a future, will wait until the future is complete, and returne ht completed value. Optionally,
   * the default timeout can be overriden to another duration
   */
  def await[A](future: Future[A], timeout: Duration = defaultTimeout) = Await.result(future, timeout)
}
