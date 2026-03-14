// nullsafe.kt - Exemple Kotlin : nullable, ?. , ?:, !!, smart cast

fun main() {
    var name: String? = "Kotlin"
    println(name)

    // Safe call ?.
    val len: Int? = name?.length
    println(len)

    // Elvis ?:
    val safe: Int = len ?: 0
    println(safe)

    // Null assignment
    name = null
    val def: String = name ?: "default"
    println(def)

    // Not-null assertion !!
    var msg: String? = "Hello"
    val sure: String = msg!!
    println(sure)
}
