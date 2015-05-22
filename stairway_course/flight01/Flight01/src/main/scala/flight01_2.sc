case class Award(name: String,
                 outcome: String)
// outcome is "Won" or "Nominated"
trait Person {
  def awards: List[Award]
  def awardsWon =
    awards.filter(_.outcome == "Won")
}

case class Actor2 (awards: List[Award]) extends Person

val valKilmer = Actor2(
  Award ("Best Bottom Award", "Won") ::
    Award ("Best Pecs Award", "Won")  :: Nil
)

valKilmer.awardsWon.map(_.name).toString


trait Production {
  def releaseYear : Int
}

case class Film (releaseYear: Int) extends Production

case class Series(year: Int)

case class TvShow ( series: List[Series]) extends Production {
  def releaseYear: Int = series.sortBy(_.year).head.year
}


val blackAdder = TvShow( Series(1983) :: Series(1985) :: Series(1990) :: Nil)

blackAdder.releaseYear

object Countries {

  val countries = "US" :: "ZH" :: "GB" :: Nil

  def supported(c: String) = countries.contains(c)
}

Countries.supported("FR")

sealed trait Outcome
case object Nominated extends Outcome
case object Won extends Outcome
case class Award2(outcome: Outcome)
val award1 = Award2(Nominated)
val award2 = Award2(Won)


val x: Outcome = Won
x match {
    case Won => "Yoooo"
    case Nominated => "Tut"

}

val msg = award2 match {
  case Award2(Nominated) => "Meh...."
  case Award2(Won) => "Wooooooo...."
  case Award2(_) =>"Crap..."
}

