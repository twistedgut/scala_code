package test

import scala.util.Random

object TestData {
  
  def randomString(n: Int) = Random.alphanumeric.take(n).mkString

  def code = randomString(3)

}
