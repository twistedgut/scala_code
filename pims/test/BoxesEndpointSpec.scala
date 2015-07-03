import controllers.BoxesEndpoint
import org.specs2.runner._
import org.specs2.mock.Mockito
import org.junit.runner.RunWith
import play.api._
import play.api.mvc._
import play.api.test._
import play.api.test.Helpers._
import play.api.libs.json._
import domain.Box
import repository.Boxes
import scala.util._
import scala.concurrent._
import domain.Formats
import org.specs2.specification.Scope

@RunWith(classOf[JUnitRunner])
class BoxesEndpointSpec extends PlaySpecification with Results with Mockito {

  import ExecutionContext.Implicits.global

  trait MockBoxes extends Boxes {
    override val boxes = mock[BoxesRepository]
  }

  trait TestEndpoint extends Controller with BoxesEndpoint with MockBoxes with Formats with Scope

  "create new boxes" in new TestEndpoint {
    // given
    boxes.store(any[Box]) returns Future.successful(())

    val body = Json.parse(
                 """{
                    "code": "box1",
                    "name": "Box 1",
                    "business_code": "bus1"
                 }""")

    // when
    val result: Future[Result] = create().apply(FakeRequest(POST, "/box").withBody(body))

    // then
    there was one(boxes).store(Box("box1", "Box 1", "bus1"))
  }

}
