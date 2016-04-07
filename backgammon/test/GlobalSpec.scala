import play.api.test.PlaySpecification
import domain.InvalidEntity

object GlobalSpec extends PlaySpecification {

  "Global" should {

    "return bad request (400) on invalid entity" in {
      status(Global.onError(null, new InvalidEntity(Seq()))) mustEqual BAD_REQUEST
    }

  }

}