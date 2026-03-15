-- test_meta.lua : test des metatables et metamethodes (TODO 16)

-- Test 1 : setmetatable et getmetatable
local t = {10, 20, 30}
local mt = {}
setmetatable(t, mt)
local m = getmetatable(t)
print(m)

-- Test 2 : __index via table
local defaults = {x = 100, y = 200}
local obj = {}
local mt2 = {}
mt2.__index = defaults
setmetatable(obj, mt2)
print(obj.x)
print(obj.y)

-- Test 3 : rawget (acces sans __index)
local v = rawget(obj, 1)
print(v)

-- Test 4 : rawset (affectation directe)
rawset(obj, 1, 42)
print(obj[1])

-- Test 5 : getmetatable retourne nil si pas de metatable
local plain = {1, 2, 3}
local pm = getmetatable(plain)
print(pm)
