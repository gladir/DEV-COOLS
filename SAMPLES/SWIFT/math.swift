// math.swift - Fonctions arithmetiques compilees par SWIFT86
// Demontre : func, parametres, inout, return, recursion

func add(_ a: Int, _ b: Int) -> Int {
    return a + b
}

func multiply(_ a: Int, _ b: Int) -> Int {
    return a * b
}

func factorial(_ n: Int) -> Int {
    if n <= 1 {
        return 1
    }
    return n * factorial(n - 1)
}

func swap(_ a: inout Int, _ b: inout Int) {
    let temp: Int = a
    a = b
    b = temp
}

let x: Int = 10
let y: Int = 20
let sum: Int = add(x, y)
let product: Int = multiply(x, y)
let fact5: Int = factorial(5)

print(sum)
print(product)
print(fact5)
