package repository

// Helper class that produces unique values for database queries.
// The Counter simply generates unique Long values -- the user
// provides a function for turning them into something meaningful.
case class Counter[A](func: Long => A) {
  private var suffix = System.currentTimeMillis
  def next(): A = {
    // We can't simply use System.currentTimeMillis here because
    // we sometimes generate more than one value a millisecond.
    suffix += 1
    func(suffix)
  }
}
