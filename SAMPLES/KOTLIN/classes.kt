// classes.kt - Exemple Kotlin : class, data class, constructeur, proprietes

class Point(val x: Int, val y: Int) {
    fun show() {
        println(x)
        println(y)
    }
}

data class Pair(val first: Int, val second: Int)

fun main() {
    val p: Point = Point(3, 7)
    p.show()
    println(p.x)

    val pair: Pair = Pair(10, 20)
    println(pair.first)
    println(pair.second)
}
