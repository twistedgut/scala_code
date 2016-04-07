package test

import domain.SmcCurrency

object TestCurrency {

  val nameCodeGenerator = Counter { suffix =>
    (s"code-$suffix", s"Name ($suffix)")
  }

  def apply() = {
    val (genCode, genName) = nameCodeGenerator.next()
    SmcCurrency(genName, genCode)
  }
}