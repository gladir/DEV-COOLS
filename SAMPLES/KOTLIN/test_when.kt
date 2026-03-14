val x = 2
when (x) {
    1 -> println("un")
    2 -> println("deux")
    3 -> println("trois")
    else -> println("autre")
}
val y = 5
when (y) {
    1, 2, 3 -> println("petit")
    4, 5 -> println("moyen")
    else -> println("grand")
}
println("fin")
