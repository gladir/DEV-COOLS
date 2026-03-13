// lambda.kt - Exemple Kotlin : lambdas, fonctions d ordre superieur, extension

fun apply(x: Int, f: (Int) -> Int): Int {
    return f(x)
}

fun Int.double(): Int {
    return this * 2
}

fun main() {
    // Fonction d ordre superieur avec lambda
    val result: Int = apply(5, { it * 3 })
    println(result)

    // Extension function
    val d: Int = 7.double()
    println(d)

    // Scope function let
    val v: Int = 10
    v.let {
        println(it)
    }
}
