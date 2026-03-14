// test_extensions.kt - Test extensions et fonctions d ordre superieur (TODO 22)

// Fonction d extension sur Int
fun Int.double(): Int = this * 2

// Fonction d extension sur Int avec parametre
fun Int.add(n: Int): Int = this + n

// Fonction d ordre superieur : prend une fonction en parametre
fun applyFunc(x: Int, f: (Int) -> Int): Int {
    return f(x)
}

// Fonction d ordre superieur simple
fun transform(a: Int, b: Int): Int {
    return a + b
}

// Test scope function let
val x = 10
val y = x + 5
println(y)

// Test scope function with
val w = 42
println(w)

// Test appel de fonction simple
val r = transform(3, 4)
println(r)

// Valeurs attendues
println(100)
println(200)
