package scripts

import java.io.{File, PrintWriter}
import scala.util.{Failure, Success}

object GenerateNewAvailabilitySql extends SqlGeneratorMethods {
  def main(args: Array[String]): Unit = {
    val filePath   = args(0)
    val dc         = args(1).toUpperCase
    val xtClass    = args(2)
    val xtExpress  = args(3)

    getFileContentsWithHeaders(filePath) match {
      case Success(lines) =>
        writeSqlToFile(lines, dc, xtClass, xtExpress)
      case Failure(ex) =>
        println(s"** ERROR **\nThere has been a problem accessing the CSV file $filePath [${ex.getMessage}]\n***********")
    }
  }

  def writeSqlToFile(lines: List[Map[String,String]], dc: String, xtClass: String, xtExpress: String) = {
    val nowTime  = System.currentTimeMillis.toString
    val avwriter = new PrintWriter(new File(s"SOS_${dc.toLowerCase}_insert_new_availabilities_$nowTime.sql"))
    val xtwriter = new PrintWriter(new File(s"XT_${dc.toLowerCase}_insert_new_shipping_charges_$nowTime.sql"))
    avwriter.write("BEGIN;\n\n")
    xtwriter.write("BEGIN;\n\n")
    for (line <- lines) {
      val filteredLine = line.filter(!_._2.trim.isEmpty)
      avwriter.write(generateSosInsertSql(filteredLine, dc))
      if (filteredLine.keySet.contains("country")) {
        xtwriter.write(generateXtInsertSql(filteredLine, dc, xtClass, xtExpress))
      }
    }
    avwriter.write("\nCOMMIT;")
    xtwriter.write("\nCOMMIT;")
    avwriter.close()
    xtwriter.close()
  }

  def generateSosInsertSql(line: Map[String,String], dc: String): String = {
    // Optional elements - lists are filtered to remove columns that have no data provided in the csv file
    val avOptCodeParams    = Seq("country", "division", "post_code_group", "packaging_group").filter(line.keySet.contains)
    val avOptStringParams  = Seq("customer_selectable_offset", "customer_selectable_cutoff_time").filter(line.keySet.contains)
    val promoGroup         = "promotion_groups"
    // Get the csv data, process as appropriate and aggregate the values
    val insertStatementValues =
      avReqCodeParams.map(s => getSelectNoIdentifier(processTableName(s), line.get(s))) ++
        avOptCodeParams.map(s => generateSelectStatement(processTableName(s),
          line.getOrElse(s, ""), "id", "code", true)) ++
        avReqStringParams.map(s => stringToSqlString(getRequiredParameter(s, line.get(s)))) ++
        avOptStringParams.map(s => stringToSqlString(line.getOrElse(s, "")))
    // Process the column names that require '_id' adding and aggregate the column names
    val allCodeColumns = avReqCodeParams.map(s => s + "_id") ++ avOptCodeParams.map(s => s + "_id")
    val insertStatementColumns = allCodeColumns ++ avReqStringParams ++ avOptStringParams
    // Create insert SQL statement for availability creation
    val insertAvSql = "INSERT INTO shipping.availability(" + insertStatementColumns.mkString(",") + ",\"DC\") VALUES (" + insertStatementValues.mkString(",") +s",'$dc')"
    // Add promotion group SQL if the optional 'promotion_groups' is populated
    // Generate SQL, adding promotion group insert to availability
    if ( line.keySet.contains(promoGroup) ) {
      val selectPromo = generateSelectStatement(processTableName("promotion_group"),
        line.getOrElse(promoGroup, ""), "id", "name", true)
      s"WITH inserted AS ( $insertAvSql RETURNING * ) " +
        "INSERT INTO shipping.availability_promotion_group(availability_id, promotion_group_id) " +
        s"VALUES ( (SELECT id FROM inserted), $selectPromo);\n"
    }
    else {
      // If no promotion groups are provided, just the insert availability SQL is provided
      insertAvSql + ";\n"
    }
  }

  def generateXtInsertSql(line: Map[String, String], dc: String, xtClass: String, xtExpress: String): String = {
    // get required strings from the csv data
    val xtInsertStatementValues =
      reqStringParams.map(s => stringToSqlString(getRequiredParameter(s, line.get(s))))
    // use map to get option name used in XT description
    val option = getRequiredParameter("option", line.get("option"))
    val optionName = stringToSqlString(mapXtOptionName.getOrElse(option, ""))
    val xtReqSelectParams = Seq("country", "currency", "business").map(
      s => stringToSqlString(getRequiredParameter(s, line.get(s))))
    // generate other parts of SQL for retrieval of the description, currency and channel (aka business)
    val descriptionSql = s"(SELECT concat_ws(' ', country, $optionName) FROM country WHERE code = ${xtReqSelectParams(0)})"
    val currencySql = s"(SELECT id FROM currency WHERE currency = ${xtReqSelectParams(1)})"
    val channelSql = s"(SELECT id FROM channel WHERE name = (SELECT name FROM sos.channel WHERE api_code = ${xtReqSelectParams(2)}))"

    // aggregate all data into insert SQL statement
    "INSERT INTO shipping_charge(sku, charge, is_enabled, is_customer_facing, description, currency_id, " +
      "channel_id, flat_rate, class_id, is_express) VALUES (" + xtInsertStatementValues.mkString(",") + s",$descriptionSql" + s",$currencySql" +
      s",$channelSql,true,$xtClass, $xtExpress);\n"
  }

  def processTableName (s: String) = {
    val shippingTables = Seq("option", "signature_required_status", "packaging_group", "promotion_group")
    shippingTables.contains(s) match {
      case true  => s"shipping.$s"
      case false => s"public.$s"
    }
  }

  // Required elements to create new availability
  // Different types of input are treated differently, for example, some parameters provide codes that need
  // to be translated into ids, others are processed simply as strings
  val avReqCodeParams    = Seq("option", "business", "currency", "signature_required_status")
  val reqStringParams    = Seq("legacy_sku", "price", "is_enabled", "is_customer_facing")
  val avReqStringParams  = reqStringParams ++ Seq("does_price_include_tax")
  // Map of SOS option codes and description names used in XT
  val mapXtOptionName = Map("STANDARD" -> "Standard", "EXPRESS" -> "Express", "NEXTDAY" -> "Next Day",
    "COURIER" -> "Courier", "NOMDAY" -> "Nominated Day")

}