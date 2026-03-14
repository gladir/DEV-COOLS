-- test_stdlib.lua : test bibliotheque standard (TODO 20)

-- Test 1 : math.abs
print(math.abs(-5))
print(math.abs(3))

-- Test 2 : math.max / math.min
print(math.max(10, 20))
print(math.min(10, 20))

-- Test 3 : math.floor / math.ceil (pass-through)
print(math.floor(7))
print(math.ceil(7))

-- Test 4 : math.sqrt
print(math.sqrt(16))
print(math.sqrt(100))

-- Test 5 : math.pi / math.huge / math.maxinteger / math.mininteger
print(math.pi)
print(math.huge)
print(math.maxinteger)
print(math.mininteger)

-- Test 6 : math.random (seed for reproducibility)
math.randomseed(42)
local r = math.random(1, 10)
print(r)

-- Test 7 : math.tointeger / math.type
print(math.tointeger(42))
print(math.type(5))

-- Test 8 : os.exit is tested indirectly (would halt)
-- os.exit(0)

-- Test 9 : os.clock
local c = os.clock()
print(c)
