package repository

import org.specs2.mutable.Specification
import org.specs2.runner._
import org.junit.runner._
import org.specs2.specification._
import domain.Box
import scala.concurrent.Await
import scala.concurrent.duration._
import test.TestData

@RunWith(classOf[JUnitRunner])
class SlickBoxesSpec extends Specification {

  trait TestSlickBoxes extends SlickBoxes with MySqlDatabase with TestDatabase with SlickTables with Scope {
    val code = TestData.code
  }

  "SlickBoxes" should {

    "create box record on create" in new TestSlickBoxes {
      // given
      val box = Box(s"/dc1/inner/$code", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.boxForCode(s"/dc1/inner/$code") must_== (s"/dc1/inner/$code", "Box 1")
    }

    "create business link on create box" in new TestSlickBoxes {
      // given
      val box = Box(s"/dc1/inner/$code", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.businessesForBox(s"/dc1/inner/$code") must contain("bus1")
    }

    "create distribution centre relationship on create box" in new TestSlickBoxes {
      // given
      val box = Box(s"/dc1/inner/$code", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.dcForBox(s"/dc1/inner/$code") must_== Some("dc1")
    }

    "create matching entry in quantity table on create box" in new TestSlickBoxes {
      // given
      val box = Box(s"/dc1/inner/$code", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.quantity(s"/dc1/inner/$code") must_== Some(0)
    }
  }

}
