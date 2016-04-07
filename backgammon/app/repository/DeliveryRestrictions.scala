package repository

import activemq.AmqResendMessageProducer
import domain.deliveryrestrictions.{DeliveryRestriction, DeliveryRestrictionResend, DeliveryRestrictionUpdate}
import domain.activemq._

import scala.concurrent.Future

trait DeliveryRestrictions {
  val deliveryRestrictions: RestrictionsRepository

  trait RestrictionsRepository {

    /**
     * Returns all shipping options.
     */
    def get(shippingAvailabilityIds: List[Int], fromDate: String, toDate: String, stages: List[String]): Future[Seq[DeliveryRestriction]]

    def update(restrictions: Seq[DeliveryRestrictionUpdate]): Future[Boolean]

    def resend(res: DeliveryRestrictionResend): Future[AmqResendMessageProducer]

    def blah(op: String, fromDate: String, toDate: String, dcCode: String): Future[Boolean]

    /**
      * Returns all restrictions between specified dates for TON AMQ messages.
      */
    def getAmqChannelRestrictions(restrictionWindow: RestrictionWindow): Future[Seq[AmqChannelRestriction]]

    def getRestrictionWindow(restrictions: Seq[DeliveryRestrictionUpdate]): RestrictionWindow

    def getAvailabilityDc(res: DeliveryRestrictionUpdate): Future[String]

  }

}
