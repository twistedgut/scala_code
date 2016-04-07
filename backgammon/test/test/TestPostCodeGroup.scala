package test

import domain.SmcPostCodeGroup

object TestPostCodeGroup {

  val nameCodeGenerator = Counter { suffix =>
    (s"code-$suffix", s"Name ($suffix)")
  }

  def apply() = {
    val (genCode, genName) = nameCodeGenerator.next()
    SmcPostCodeGroup(genName, genCode)
  }
}
