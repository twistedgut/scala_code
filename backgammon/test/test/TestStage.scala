package test
import domain.options.SmcStage

object TestStage {

  val nameCodeGenerator = Counter { suffix =>
    (
      s"code-$suffix",
      s"Name ($suffix)"
      )
  }
  def apply(ranking: Int) = {
    val (genCode, genName) = nameCodeGenerator.next()
    SmcStage(genName, genCode, ranking)

  }
}
