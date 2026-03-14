// test_classes.kt - Test classes et data classes (TODO 16)

class Point(val x: Int, val y: Int)

data class Person(val name: String, val age: Int)

val p = Point(10, 20)
println(p.x)
println(p.y)

val alice = Person("Alice", 30)
println(alice)
println(alice.name)
println(alice.age)

val bob = Person("Bob", 25)
println(bob)
