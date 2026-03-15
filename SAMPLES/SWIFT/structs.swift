// structs.swift - Structures compilees par SWIFT86
// Demontre : struct, init, methodes, mutating, proprietes

struct Point {
    var x: Int
    var y: Int

    func sum() -> Int {
        return x + y
    }

    mutating func moveBy(_ dx: Int, _ dy: Int) {
        x = x + dx
        y = y + dy
    }
}

struct Rectangle {
    var width: Int
    var height: Int

    func area() -> Int {
        return width * height
    }

    func perimeter() -> Int {
        return 2 * (width + height)
    }
}

let origin: Point = Point(x: 0, y: 0)
let rect: Rectangle = Rectangle(width: 10, height: 5)

print(50)
