package scripts

import java.io.File
import com.github.tototoshi.csv.CSVReader
import repository.ErrorMessageException
import scala.util.Try

trait SqlGeneratorMethods {

  // Generates a simple '(select x from y where blah = whatever)' SQL statement
  def getSelectNoIdentifier (p: String, o: Option[String]) = o match {
    case Some(s) => getIdFromCode(p, s, true)
    case None    => throw ErrorMessageException(s"Required parameter [$p] is missing.")
  }

  // Generates a 'x_id = (select x from y where blah = whatever)' SQL statement
  def getSelectWithIdentifier (p: (String, String), s: Option[String]): String = s match {
    case Some(op) =>
      p._1 + " = " + getIdFromCode(p._2, op, true)
    case None => throw ErrorMessageException(s"Required parameter [$p] is missing.")
  }

  def generateSelectStatement (t: String, s: String, col1: String, col2: String, parenth: Boolean) = parenth match {
    case true => s"(SELECT $col1 FROM $t WHERE $col2 = '$s')"
    case false => s"SELECT $col1 FROM $t WHERE $col2 = '$s'"
  }

  def getIdFromCode (t: String, s: String, p: Boolean) =
    generateSelectStatement(t, s, "id", "code", p)

  // Throw an error if a required parameter is missing
  def getRequiredParameter (p: String, o: Option[String]) = o match {
    case Some(s) => s
    case None    => throw ErrorMessageException(s"Required parameter [$p] is missing.")
  }

  // Need to wrap strings in single quotes for use in SQL statements
  // In doing so single quotes must be escaped (e.g. l'envoi -> l''envoi)
  def stringToSqlString (s: String) = {
    // need to escape single quotations for inclusion in SQL queries
    val escapedS = s.replaceAll("'", "''")
    s"'$escapedS'"
  }

  // Returns a map of column headers and values (e.g. "option" -> "NEXTDAY" and so on)
  def getFileContentsWithHeaders( path: String ): Try[List[Map[String, String]]] = for {
    reader <- Try(CSVReader.open(new File(path)))
  } yield reader.allWithHeaders()

  // Returns a list of all csv rows, which are represented as a list of strings  (i.e. List[List[String]])
  def getFileContents( path: String ): Try[List[List[String]]] = for {
    reader <- Try(CSVReader.open(new File(path)))
  } yield reader.all()

}
