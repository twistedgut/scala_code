package test

import domain.SmcBusiness

object TestBusiness  {

  val nameCodeGenerator = Counter { suffix =>
    (s"code-$suffix", s"Name ($suffix)")
  }

  def apply() = {
    val (genCode, genName) = nameCodeGenerator.next()
    SmcBusiness(genName, genCode)
  }
}