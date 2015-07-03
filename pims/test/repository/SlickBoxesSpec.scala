package repository

import org.specs2.mutable.Specification
import org.specs2.runner._
import org.junit.runner._
import org.specs2.specification._
import domain.Box
import scala.concurrent.Await
import scala.concurrent.duration._

@RunWith(classOf[JUnitRunner])
class SlickBoxesSpec extends Specification {

  trait TestSlickBoxes extends SlickBoxes with InMemoryDatabase with TestDatabase with SlickTables with Scope

  "SlickBoxes" should {

    "create box record on create" in new TestSlickBoxes {
      // given
      database.created
      val box = Box("/dc1/inner/box1", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.boxForCode("/dc1/inner/box1") must_== ("/dc1/inner/box1", "Box 1")

    }

    "create business link on create box" in new TestSlickBoxes {
      // given
      database.created
      val box = Box("/dc1/inner/box1", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.businessesForBox("/dc1/inner/box1") must contain("bus1")
    }

    "create data centre relationship on create box" in new TestSlickBoxes {
      // given
      database.created
      val box = Box("/dc1/inner/box1", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.dcForBox("/dc1/inner/box1") must_== Some("dc1")
    }

    "create matching entry in quantity table on create box" in new TestSlickBoxes {
      // given
      database.created
      val box = Box("/dc1/inner/box1", "Box 1", "bus1")

      // when
      Await.result(boxes store box, 1.seconds)

      // then
      database.quantity("/dc1/inner/box1") must_== Some(0)
    }
  }

}
