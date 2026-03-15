// test_scope.kt - Test portee, pile et cadres (TODO 18)

// Test 1 : variables locales dans une fonction
fun add(a: Int, b: Int): Int {
    val sum = a + b
    return sum
}

println(add(3, 7))

// Test 2 : portee de bloc - variable locale dans un if
val x = 10
if (x > 5) {
    val localVar = x + 1
    println(localVar)
}
println(x)

// Test 3 : portee de bloc dans une boucle while
var counter = 0
while (counter < 3) {
    val temp = counter * 2
    println(temp)
    counter = counter + 1
}

// Test 4 : portee de bloc dans une boucle for
for (i in 1..3) {
    val doubled = i * 2
    println(doubled)
}

// Test 5 : fonction avec plusieurs variables locales
fun compute(a: Int, b: Int): Int {
    val sum = a + b
    val diff = a - b
    val product = sum * diff
    return product
}

println(compute(5, 3))

// Test 6 : fonctions imbriquees - registres SI DI preserves
fun outer(n: Int): Int {
    val a = n + 1
    return a * 2
}

println(outer(4))

// Test 7 : portee else
val y = 3
if (y > 10) {
    println(99)
} else {
    val msg = y + 100
    println(msg)
}
