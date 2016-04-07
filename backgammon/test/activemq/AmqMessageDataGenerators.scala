package activemq

import java.sql.Date

import akka.actor.{ActorSystem, Props}
import akka.camel.CamelExtension
import domain.activemq.{AmqChannelRestriction, AmqDeliveryRestriction, RestrictionMessage, RestrictionWindow}
import org.apache.activemq.camel.component.ActiveMQComponent
import test.{Counter, TestDC}

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

trait AmqMessageDataGenerators {

  val genTodayDate    = new Date(System.currentTimeMillis()).toString
  val genTomorrowDate = new Date(System.currentTimeMillis() + 24 * 60 * 60 * 1000).toString
  val genDcCode       = TestDC().code
  // The channel information is hard-coded as it performs a config look-up
  val genChannel      = "NAP"
  val genChannelName  = "NAP_INTL"
  val stage           = "testing"
  val hostName        = "TestingActor"

  val genLegacySku = Counter { suffix =>
    s"LegacySku-$suffix"
  }
  val testLegacySku = genLegacySku.next()

  def testActorSystem = ActorSystem(hostName)

  def genRestrictionWindow: RestrictionWindow = {
    RestrictionWindow(
      genTodayDate,
      genTomorrowDate
    )
  }

  def genRestrictionMessage = {
    RestrictionMessage(
      genChannelName,
      Seq(genAmqDeliveryRestriction),
      genRestrictionWindow
    )
  }

  def genAmqDeliveryRestriction: AmqDeliveryRestriction = {
    AmqDeliveryRestriction(
      genTomorrowDate,
      stage,
      testLegacySku
    )
  }

  def genAmqMessenger = {
    AmqMessageProducer(
      Future {
        genDcCode
      },
      genRestrictionWindow,
      Future {
        Seq(AmqChannelRestriction(genAmqDeliveryRestriction, genChannel))
      },
      testActorSystem
    )
  }

  def genTestActorRef = {
    val system = CamelExtension(testActorSystem)
    system.context.addComponent("activemq", ActiveMQComponent.activeMQComponent("tcp://test:9999"))
    testActorSystem.actorOf(Props[TestAmqProducer])
  }

}
