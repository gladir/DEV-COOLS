-- test_binexpr.lua : test TODO 11 - Expressions binaires (Pratt)

-- Arithmetique de base avec variables
local a = 10
local b = 3
print(a + b)
print(a - b)
print(a * b)

-- Division et modulo
local c = 17
local d = 5
print(c / d)
print(c // d)
print(c % d)

-- Pliage de constantes
local e = 2 + 3 * 4
print(e)
local f = 100 // 7
print(f)

-- Comparaisons
local g = 10
local h = 20
print(g == h)
print(g ~= h)
print(g < h)
print(g <= h)
print(g > h)
print(g >= h)

-- Court-circuit and/or avec constantes
local t = true and 42
print(t)
local u = false and 99
print(u)
local v = nil or 7
print(v)
local w = 5 or 99
print(w)

-- Court-circuit and/or avec variables
local x = 10
local y = 0
local z = x and 42
print(z)
local r = y and 99
print(r)
local s = x or 77
print(s)
local q = y or 88
print(q)

-- Puissance avec constantes
local p1 = 3 ^ 0
print(p1)
local p2 = 5 ^ 1
print(p2)
local p3 = 4 ^ 2
print(p3)

-- Concatenation avec variables
local sa = "hello"
local sb = "world"
print(sa .. sb)

-- Combinaison de precedences
local m = 2 + 3 * 4 - 1
print(m)
