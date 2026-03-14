// test_runtime.kt - TODO 24 : Runtime minimal

fun main() {
    // Test print basique
    println(100)

    // Test arithmetique basique
    val a = 5
    val b = 10
    val c = a + b
    println(c)

    // Test conditions
    if (c > 10) {
        println(1)
    } else {
        println(0)
    }

    // Test boucle
    var i = 0
    while (i < 3) {
        println(i)
        i = i + 1
    }

    // Test chaines
    val msg = "hello"
    println(msg)

    // Test array
    val arr = intArrayOf(3, 1, 2)
    println(arr[0])
}
