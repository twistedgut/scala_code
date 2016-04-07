package domain

case class InvalidEntity(messages: Seq[String]) extends Exception(messages mkString "\n")