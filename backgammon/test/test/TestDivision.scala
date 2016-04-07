package test

import domain.{SmcCountry, SmcDivision}

object TestDivision {

  val nameCodeGenerator = Counter { suffix =>
    (s"code-$suffix", s"Name ($suffix)")
  }

  //Todo: Hardcoded DC - get real one when endpoint becomes available

  def apply(country: SmcCountry = TestCountry()) = {
    val (genCode, genName) = nameCodeGenerator.next()
    SmcDivision(genName, genCode, country.code)
  }
}