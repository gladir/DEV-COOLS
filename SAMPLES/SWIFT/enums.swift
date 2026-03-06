// enums.swift - Enumerations compilees par SWIFT86
// Demontre : enum, raw values, valeurs associees, pattern

enum Direction {
    case north
    case south
    case east
    case west
}

enum Planet: Int {
    case mercury = 1
    case venus = 2
    case earth = 3
    case mars = 4
}

let dir: Int = 0
let earth: Int = 3

switch dir {
case 0:
    print(1)
case 1:
    print(2)
case 2:
    print(3)
case 3:
    print(4)
default:
    print(0)
}

print(earth)
