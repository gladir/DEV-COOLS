// control.swift - Structures de controle compilees par SWIFT86
// Demontre : if/else, guard, switch/case, pattern matching

let score: Int = 85

if score >= 90 {
    print(1)
} else if score >= 80 {
    print(2)
} else if score >= 70 {
    print(3)
} else {
    print(0)
}

let value: Int = 3
switch value {
case 1:
    print(10)
case 2:
    print(20)
case 3:
    print(30)
default:
    print(0)
}

func checkAge(_ age: Int) -> Int {
    guard age >= 0 else {
        return 0
    }
    guard age <= 150 else {
        return 0
    }
    return 1
}

let valid: Int = checkAge(25)
print(valid)
