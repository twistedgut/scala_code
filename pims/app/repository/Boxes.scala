package repository

import domain.Box

import scala.concurrent.Future
import scala.util.Try

trait Boxes {

  val boxes: BoxesRepository

  trait BoxesRepository {
    def store(box: Box): Future[Unit]
  }

}
