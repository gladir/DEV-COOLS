// optionals.swift - Optionnels compiles par SWIFT86
// Demontre : Optional, if let, guard let, ??, chaining

var maybeValue: Int? = 42
var noValue: Int? = nil

// Nil-coalescing
let result: Int = maybeValue ?? 0
print(result)

// Forced unwrap (avec valeur)
let forced: Int = maybeValue!
print(forced)

let defaulted: Int = noValue ?? 99
print(defaulted)
