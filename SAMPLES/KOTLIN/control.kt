// control.kt - Exemple Kotlin : if/else, when, while, for, ranges

fun main() {
    val x: Int = 15

    // if / else
    if (x > 10) {
        println("grand")
    } else {
        println("petit")
    }

    // when
    val day: Int = 3
    when (day) {
        1 -> println("Lundi")
        2 -> println("Mardi")
        3 -> println("Mercredi")
        else -> println("Autre")
    }

    // while
    var i: Int = 0
    while (i < 5) {
        println(i)
        i = i + 1
    }

    // for range
    for (n in 1..5) {
        println(n)
    }
}
