val degas = 2

val vang = 3

degas * vang

{
  val wang = 4.3
  degas * wang
}

val msg = "Hello, World"

println(msg)

var msg2 = "Leave me alone..."

println(msg2)

msg2 = "'ello"

println(msg2)

val grop = 2

if ( degas > vang)
  System.out.println(degas);
else
  System.out.println(vang);


val m = if (degas > vang) degas else vang
println(m)


def max (x: Int, y: Int) = {
  if (x > y) x
  else y
}

max(degas, vang)

max(1,1)

def max2(x: Int, y: Int) = if (x > y) x else y

max2(3,6)

def greet(): Unit = println("yo")

greet()

def numprint(s: String, x: Int) = {
  for(i <- 0 until x) println(s)
}

numprint("Beaver", 2)
numprint("Patrol", 2)

val grok = "Herbert"

grok.reverse.toUpperCase

def revprint(r: String, s: String, t: String): Unit = {
  println(s"${r.reverse.toUpperCase} ${s.reverse.toUpperCase} ${t.reverse.toUpperCase}")
}

revprint("Frankly", "Mister", "Shankly")

def fib(v: Int): Int = v match {
  case 0 => 0
  case 1 => 1
  case n => fib(n-1) + fib(n-2)
}

for (i <- 0 until 10) println (fib(i))













