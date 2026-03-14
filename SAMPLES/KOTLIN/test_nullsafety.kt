fun main() {
    // Nullable type declaration
    var name: String? = null

    // Elvis operator
    val len = name ?: "default"
    println(len)

    // Safe call
    var greeting: String? = "Hello"
    val upper = greeting?.length
    println(upper)

    // Not-null assertion (on non-null value)
    var x: Int? = 42
    val y = x!!
    println(y)

    // Null propagation with safe call
    var empty: String? = null
    val result = empty?.length
    println(result)

    // Elvis with expression
    val value = empty ?: "fallback"
    println(value)

    // Safe cast
    val num = 42 as? Int
    println(num)

    // Chained safe call
    var msg: String? = "world"
    println(msg?.uppercase())
}
