val degas = 2

val vang = 3

degas * vang

{
  val wang = 4.3
  degas * wang
}

val msg = "Hello, World"

println(msg)
var msg2 = "Leave me alone..."
println(msg2)
msg2 = "'ello"
println(msg2)
val grop = 2
if ( degas > vang)
  System.out.println(degas)
else
  System.out.println(vang)
val m = if (degas > vang) degas else vang
println(m)

def max (x: Int, y: Int) = {
  if (x > y) x
  else y
}
max(degas, vang)

max(1,1)

def max2(x: Int, y: Int) = if (x > y) x else y

max2(3,6)

def greet(): Unit = println("yo")

greet()

def numprint(s: String, x: Int) = {
  for(i <- 0 until x) println(s)
}
numprint("Beaver", 2)
numprint("Patrol", 2)
val grok = "Herbert"

grok.reverse.toUpperCase
def revprint(r: String, s: String, t: String): Unit = {
  println(s"${r.reverse.toUpperCase} ${s.reverse.toUpperCase} ${t.reverse.toUpperCase}")
}
revprint("Frankly", "Mister", "Shankly")
def fib(v: Int): Int = v match {
  case 0 => 0
  case 1 => 1
  case n => fib(n-1) + fib(n-2)
}
for (i <- 0 until 10) println (fib(i))
// from NAP course
def simpleRating (rating: Double): String = {
   if (rating > 8.0) "Excellent"
   else if (rating >= 4.0) "Okay"
   else "Poor"
}

simpleRating(3)
simpleRating(4.2)
simpleRating(7.99)
case class Actor(firstName: String, lastName: String) {
  // case classes come with toString defined, but it's not as pretty as this!
  // e.g. Actor(Peter,Griffin) is default toString,
  // this overridden method gives Peter Griffin
  override def toString = s"$firstName $lastName"
  def + (other: Actor) = s"$this and $other"
}
val peter = new Actor("Peter", "Griffin")
val peter2 = peter.copy(lastName = "O'Toole")
peter2.lastName
peter + peter2
Actor("Stan", "Laurel") + Actor("Oliver", "Hardy")


case class Movie ( year: Int, gross: Int, rating: Double ) {
  def badge() : String = {
    if ( year < 1960 ) "Golden Oldie"
    else if ( gross > 20 && rating > 7) "Blockbuster"
    else "Must see"
  }
}

val starwars = Movie(1977, 47, 8.9)
val casablanca = Movie(1939, 26, 9.1)
val evildead = Movie(1983, 12, 5.8)
starwars.badge()
casablanca.badge()
evildead.badge()
case class Movie2 ( name: String, rating: Double )
val pat = Movie2("Postman Pat", rating = 0.5)
val pad = Movie2("Paddington", rating = 9.2)
val greatFilm = (movie: Movie2) => movie.rating >= 7.0

greatFilm(pat)
greatFilm(pad)

val movies = List(Movie2("Evil Dead", 2.6), Movie2("Home Alone", 8.4), Movie2("Battlefield Earth", 0.7))

movies.count(greatFilm)

movies.filter(greatFilm)
movies.filter(_.name.contains("E"))
movies.map(greatFilm)
movies.map(_.name)
movies.collect{
  case Movie2(name, rating) if rating < 4 => name
}
val ballers = List("Costa", "Ballotelli", "Sanchez")
val clubs = List("Chelsea", "Liverpool", "Arsenal")
ballers zip clubs
case class Movie3(genre: String, gross: Int)
val movies2 = (100 to 5000 by 50).flatMap(g =>
  Movie3("Drama", g) :: Movie3("Romcom", g) ::
    Movie3("Action", g) :: Nil)

movies2.filter(_.genre == "Action").map(_.gross).sum
movies2.collect{ case Movie3("Action", gross) => gross}.sum
movies.map (movie =>
  if(movie.rating < 4) "Flop"
  else "Blockbuster"
)

movies.collect{
  case movie if movie.rating < 4 => "Flop"
  case _ => "Blockbuster"
}
val f: Int => String = {
  case 0 => "zero!"
  case 1 => "one!"
  case _ => "bust!"
}
f(0)
f(1)
f(3)
case class Rating(stars: Int, comment: Option[String]) {
  def asString = {
    s"$stars* " + (comment match {
      case Some(c) => s"[comment: $c]"
      case None => "[no comment]"
    })
  }
}

Rating(3, None).asString

Rating(1, Some("So awful")).asString

Rating(5, Some("A veritable tour de force")).asString

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














