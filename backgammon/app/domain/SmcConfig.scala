package domain

import com.typesafe.config.ConfigFactory
import collection.JavaConverters._

object SmcConfig {

  val config = ConfigFactory.load()
  def getString(configPath :String) = config.getString(configPath)
  def getConfig(configPath :String) = config.getConfig(configPath)
  def getStringList(configPath: String): List[String] = config.getStringList(configPath).asScala.toList

}
