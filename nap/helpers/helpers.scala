package nap.helpers

/**
  * Helper to nicely recover values from joins in slick, as in:
  * {{{
  *
  * something
  *   .map{
  *     case a ~ b ~ c =>
  *       // Do something
  *   }
  *
  * }}}
  */
object ~ {
  def unapply[A, B](in: (A, B)): Option[(A, B)] = Some(in)
}

