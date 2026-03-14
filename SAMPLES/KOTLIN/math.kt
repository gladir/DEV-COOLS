// math.kt - Exemple Kotlin : fonctions, recursion, return, expressions

fun add(a: Int, b: Int): Int {
    return a + b
}

fun factorial(n: Int): Int {
    if (n <= 1) {
        return 1
    }
    return n * factorial(n - 1)
}

fun max3(a: Int, b: Int, c: Int): Int {
    var m: Int = a
    if (b > m) {
        m = b
    }
    if (c > m) {
        m = c
    }
    return m
}

fun isEven(n: Int): Boolean {
    return n % 2 == 0
}

fun main() {
    println(add(3, 4))
    println(factorial(5))
    println(max3(10, 25, 17))
    val even: Boolean = isEven(42)
    println(even)
}
