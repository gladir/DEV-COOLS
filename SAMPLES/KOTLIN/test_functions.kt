// test_functions.kt - Test fonctions et lambdas (TODO 17)

fun add(a: Int, b: Int): Int {
    return a + b
}

fun square(x: Int): Int = x * x

fun greet(name: String) {
    println(name)
}

val result = add(3, 4)
println(result)

val sq = square(5)
println(sq)

greet("Hello")

fun max(a: Int, b: Int): Int {
    if (a > b) {
        return a
    }
    return b
}

println(max(10, 20))
println(max(30, 5))
