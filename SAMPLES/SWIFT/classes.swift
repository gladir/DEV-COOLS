// classes.swift - Classes compilees par SWIFT86
// Demontre : class, heritage, override, is, as?, vtable

class Animal {
    var name: String
    var legs: Int

    func speak() -> Int {
        return 0
    }
}

class Dog: Animal {
    var breed: String

    override func speak() -> Int {
        return 1
    }
}

class Cat: Animal {
    var indoor: Bool

    override func speak() -> Int {
        return 2
    }
}

let pet: Animal = Animal()
print(42)
