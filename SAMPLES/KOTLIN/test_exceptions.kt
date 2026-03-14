// test_exceptions.kt - TODO 23 : Exceptions (try/catch/finally/throw)

// Test 1 : try/catch simple
fun main() {
    // try/catch basique
    try {
        println(42)
        throw Exception("erreur de test")
    } catch (e: Exception) {
        println(99)
    }

    // try/catch/finally
    try {
        println(1)
    } catch (e: Exception) {
        println(0)
    } finally {
        println(2)
    }

    // throw avec type specifique
    try {
        throw IllegalArgumentException("argument invalide")
    } catch (e: IllegalArgumentException) {
        println(3)
    }

    // require (ne leve pas si condition vraie)
    require(1 == 1)

    // check (ne leve pas si condition vraie)
    check(2 == 2)

    // try comme expression
    val x = try { 10 } catch (e: Exception) { 0 }
    println(x)
}
