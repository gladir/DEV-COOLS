var x = 0
do {
    x = x + 1
    println(x)
} while (x < 3)
println("---")
for (i in 1..10) {
    if (i == 5) {
        break
    }
    println(i)
}
println("---")
for (i in 1..10) {
    if (i == 3) {
        continue
    }
    if (i == 7) {
        continue
    }
    println(i)
}
println("fin")
