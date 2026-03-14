// protos.swift - Protocoles compiles par SWIFT86
// Demontre : protocol, extension, conformite, where

protocol Drawable {
    func draw() -> Int
}

protocol Printable {
    func describe() -> Int
}

struct Circle {
    var radius: Int
}

extension Circle: Drawable {
    func draw() -> Int {
        return 1
    }
}

extension Circle: Printable {
    func describe() -> Int {
        return radius
    }
}

let c: Circle = Circle(radius: 5)
print(1)
