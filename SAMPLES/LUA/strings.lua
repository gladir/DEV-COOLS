-- strings.lua : string.sub, string.find, string.format, #

-- Longueur de chaine
local s = "hello"
print(#s)

-- string.len
print(string.len("world"))

-- string.sub : extraction de sous-chaine
print(string.sub("abcdef", 2, 4))
print(string.sub("hello world", 1, 5))

-- string.upper / string.lower
print(string.upper("hello"))
print(string.lower("WORLD"))

-- string.byte : code ASCII
print(string.byte("A"))
print(string.byte("0"))

-- string.char : caractere depuis code
print(string.char(65))
print(string.char(90))

-- string.rep : repetition
print(string.rep("ab", 3))
print(string.rep("x", 5))

-- string.reverse
print(string.reverse("hello"))
print(string.reverse("lua"))

-- string.find : recherche
print(string.find("hello world", "world"))
print(string.find("abcdef", "cd"))
print(string.find("hello", "xyz"))

-- string.gsub : remplacement
print(string.gsub("hello world", "world", "lua"))

-- string.format avec %d
print(string.format("x=%d", 42))
print(string.format("sum=%d", 100))

-- string.format avec %s
print(string.format("name=%s", "lua"))

-- Concatenation
local a = "foo"
local b = "bar"
local c = a .. b
print(c)

-- Concatenation chaine + nombre via tostring
local msg = "n=" .. tostring(42)
print(msg)
