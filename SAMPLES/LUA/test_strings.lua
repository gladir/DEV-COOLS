-- test_strings.lua : test chaines et bibliotheque string (TODO 19)

-- Test 1 : string.len
local s = "hello"
print(string.len(s))

-- Test 2 : #s (longueur)
print(#s)

-- Test 3 : string.upper / string.lower
print(string.upper("hello"))
print(string.lower("WORLD"))

-- Test 4 : string.sub
print(string.sub("abcdef", 2, 4))

-- Test 5 : string.byte
print(string.byte("A"))

-- Test 6 : string.char
print(string.char(65))

-- Test 7 : string.rep
print(string.rep("ab", 3))

-- Test 8 : string.reverse
print(string.reverse("hello"))

-- Test 9 : string.find
print(string.find("hello world", "world"))

-- Test 10 : string.find not found
print(string.find("hello", "xyz"))

-- Test 11 : string.gsub
print(string.gsub("hello world", "world", "lua"))

-- Test 12 : string.format with %d
print(string.format("x=%d", 42))

-- Test 13 : string.format with %s
print(string.format("name=%s", "lua"))
