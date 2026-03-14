// loops.swift - Boucles compilees par SWIFT86
// Demontre : while, repeat-while, for-in, break, continue

var i: Int = 0

// while loop
while i < 5 {
    print(i)
    i = i + 1
}

// repeat-while loop
var j: Int = 10
repeat {
    print(j)
    j = j - 1
} while j > 7

// for-in loop avec intervalle
for k in 0..<5 {
    print(k)
}

// for-in avec break
for m in 0..<100 {
    if m == 3 {
        break
    }
    print(m)
}

// for-in avec continue
for n in 0..<6 {
    if n == 2 {
        continue
    }
    print(n)
}
