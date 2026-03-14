// inherit.kt - Exemple Kotlin : open class, override, interface, object

interface Printable {
    fun display()
}

open class Shape(val name: String) {
    open fun area(): Int {
        return 0
    }
}

class Rectangle(val w: Int, val h: Int) : Shape("Rectangle") {
    override fun area(): Int {
        return w * h
    }
}

object Config {
    val version: Int = 1
}

fun main() {
    val r: Rectangle = Rectangle(5, 3)
    println(r.name)
    println(r.area())
    println(Config.version)
}
