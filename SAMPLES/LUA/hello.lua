-- hello.lua : print, variables locales/globales, concatenation

-- Print basique
print("Hello, world!")

-- Variables globales
greeting = "Bonjour"
name = "Lua"

-- Concatenation de chaines
print(greeting .. " " .. name .. "!")

-- Variables locales
local x = 42
local y = 10
print(x)
print(y)

-- Expressions arithmetiques simples
local sum = x + y
print(sum)

-- Affectation multiple
local a, b, c = 1, 2, 3
print(a)
print(b)
print(c)

-- Variable locale sans init (nil)
local d
print(d)

-- Reassignation
x = x + 1
print(x)

-- Concatenation avec tostring
local msg = "La reponse est " .. tostring(42)
print(msg)

-- tonumber
local n = tonumber("123")
print(n)

-- type
print(type(42))
print(type("hello"))
print(type(nil))
print(type(true))
