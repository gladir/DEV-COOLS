// generics.swift - Generiques compiles par SWIFT86
// Demontre : func generique, struct generique, contraintes

func identity<T>(_ value: T) -> T {
    return value
}

func maximum<T>(_ a: T, _ b: T) -> T {
    if a > b {
        return a
    }
    return b
}

struct Wrapper<T> {
    var value: T
}

let x: Int = identity(42)
let m: Int = maximum(10, 20)
print(x)
print(m)
