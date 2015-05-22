case class HttpRequest (
    headers: List[HttpHeader]
)

case class HttpHeader (name : String, value: String)

implicit class PimpedHttpRequest( r: HttpRequest ) {
    def headerValue(name: String) =
        r.headers.find(_.name == name)
}

val request = HttpRequest( HttpHeader("a","b") :: Nil)

request.headerValue("a")


case class Duration(mins: Int, secs: Int)

implicit class pimpDuration (d: Duration) {
  def totalSecs = d.mins * 60 + d.secs
}

val time = Duration(2, 25)

time.totalSecs

Seq(1,3,7,2,4,1,1,1,6,7,9,22).sorted

trait Seq[A] {
  def sorted[A] (implicit ord: Ordering[A]): Seq[A]
}

case class Film(year: Int)

implicit val filmOrd = new Ordering[Film] {
    def compare(x: Film, y: Film) =
        x.year.compareTo(y.year)
}

val films = Seq(Film(2011), Film(2012), Film(1930))

films.sorted


