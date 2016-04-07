package test

import domain._

object TestShippingOption {

  val nameCodeGenerator = Counter { suffix =>
    (
      s"code-$suffix",
      s"Name ($suffix)",
      if (1 == suffix % 2) true else false
      )
  }

  def apply() = {
    val (genCode, genName, isLimitedAvailability) = nameCodeGenerator.next()
    SmcShippingOption(genName, genCode, isLimitedAvailability)
  }

}
