package test

import domain.SmcCountry

object TestCountry  {

  val nameCodeGenerator = Counter { suffix =>
    (s"code-$suffix", s"Name ($suffix)")
  }

  def apply() = {
    val (genCode, genName) = nameCodeGenerator.next()
    SmcCountry(genName, genCode)
  }
}