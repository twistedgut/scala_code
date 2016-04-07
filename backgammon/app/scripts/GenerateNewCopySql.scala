package scripts

import java.io.{File, PrintWriter}
import scala.util.{Failure, Success}

object GenerateNewCopySql extends SqlGeneratorMethods {

  def main(args: Array[String]) = {
    val filePath = args(0)
    val dc = args(1).toUpperCase
    getFileContentsWithHeaders(filePath) match {
      case Success(lines) =>
        createSqlFile(lines, dc)
      case Failure(ex) =>
        println(s"** ERROR **\nThere has been a problem accessing the CSV file $filePath [${ex.getMessage}]\n***********")
    }
  }

  def createSqlFile(lines: List[Map[String, String]], dc: String): Unit = {
    val nowTime = System.currentTimeMillis.toString
    val cpwriter = new PrintWriter(new File(s"SOS_${dc.toLowerCase}_insert_new_copy_descriptions_$nowTime.sql"))
    cpwriter.write("BEGIN;\n\n")
    for (line <- lines) {
      cpwriter.write(generateInsertSql(line, dc))
    }
    cpwriter.write("\nCOMMIT;")
    cpwriter.close()
  }

  def generateInsertSql(line: Map[String, String], dc: String): String = {
    val localeParam = "locale"
    val copyCodeParams = Seq("shipping_option", "business")
    val copyStringParams = Seq("name", "title", "public_name", "public_title", "short_delivery_description",
      "long_delivery_description", "estimated_delivery", "delivery_confirmation", "cut_off_weekday", "cut_off_weekend")
    // Remove any elements whose value is an empty string
    val filteredLine = line.filter(!_._2.trim.isEmpty)

    // Optional parameters
    val copyCodeOptParams = Seq("country", "division", "post_code_group").filter(filteredLine.keySet.contains)

    val insertSqlHeader = "INSERT INTO shipping.description(locale_id,shipping_availability_id,name,title,public_name,public_title,short_delivery_description," +
      "long_delivery_description,estimated_delivery,delivery_confirmation,cut_off_weekday,cut_off_weekend) VALUES ("

    // Get values required for insert SQL statement
    val getLocaleIdSql = generateLocaleSql(getRequiredParameter(localeParam, filteredLine.get(localeParam)))
    val codeParamsSql = (copyCodeParams ++ copyCodeOptParams).map(
      s => getSelectWithIdentifier(processTableName(s), filteredLine.get(s)))
    val availabilitySql = "(SELECT id FROM shipping.availability WHERE " + codeParamsSql.mkString(" AND ") + " AND \"DC\" = " + s"'$dc')"
    val copyStringsSql = copyStringParams.map(s => stringToSqlString(filteredLine.getOrElse(s, "")))

    s"$insertSqlHeader $getLocaleIdSql, $availabilitySql, " + copyStringsSql.mkString(", ") + ");\n"
  }

  def generateLocaleSql(s: String): String = {
    val localeTokens = s.split("-").map(stringToSqlString)
    "(SELECT id FROM locale WHERE " +
      s"country_id = (SELECT id FROM country WHERE code = ${localeTokens(1)}) AND " +
      s"language_id = (SELECT id FROM language WHERE code = ${localeTokens(0)}))"
  }

  def processTableName(s: String): (String, String) = s match {
    case "shipping_option" => ("option_id", "shipping.option")
    case _ => (s + "_id", s)
  }

}

