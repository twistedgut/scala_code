package activemq

import play.api.libs.json.Json
import play.api.test.{PlaySpecification, WithApplication}


class AmqMessageProducerSpec extends PlaySpecification with AmqMessageDataGenerators {

  "Get AMQ message" should {
    "Return the correct data in the message body and header" in new WithApplication {

      val result = genAmqMessenger.createAmqMessage(
        genDcCode,
        genChannel,
        Seq(genAmqDeliveryRestriction),
        genRestrictionWindow
      )

      val expectedBody = Json.toJson(genRestrictionMessage).toString
      val expectedChannel = genChannelName

      result.body mustEqual expectedBody

      result.map.get("channel_name") match {
        case Some(channel) => channel mustEqual expectedChannel
        case None => failure("No channel name found")
      }

    }
  }

  "Get actor ref" should {
    "contain the same system name as the ActorSystem provided" in new WithApplication {

      val result = genAmqMessenger.getActorRef(testActorSystem)

      val expected = hostName

      result.path.address.system mustEqual expected

    }
  }

  "Send AMQ message" should {
    "return true" in new WithApplication() {

      val amqMessenger = genAmqMessenger

      val msg = amqMessenger.createAmqMessage(
        genDcCode,
        genChannel,
        Seq(genAmqDeliveryRestriction),
        genRestrictionWindow
      )

      val aRef = amqMessenger.getActorRef(testActorSystem)

      val result = amqMessenger.sendAmqMessage(aRef, msg)

      result mustEqual true

    }
  }

}
