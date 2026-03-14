// test_inherit.kt - Test heritage, interfaces et objets (TODO 21)

// Interface avec methode abstraite
interface Drawable {
    fun draw()
}

// Classe de base ouverte (permet heritage)
open class Shape(val name: String)

// Classe enfant heritant de Shape et implementant Drawable
class Circle(val radius: Int) : Shape("circle"), Drawable {
    override fun draw() {
        println(radius)
    }
}

// Classe abstraite
abstract class Animal(val species: String) {
    abstract fun speak()
}

// Classe concrete heritant d une classe abstraite
class Dog(val breed: String) : Animal("dog") {
    override fun speak() {
        println(42)
    }
}

// enum class
enum class Direction {
    NORTH, SOUTH, EAST, WEST
}

// object singleton
object Config {
    fun getVersion(): Int {
        return 1
    }
}

// Test instanciation
val c = Circle(5)
println(c.radius)

val d = Dog("labrador")
println(d.species)

// Valeurs simples
println(100)
println(200)
