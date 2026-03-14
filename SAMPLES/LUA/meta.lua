-- meta.lua : metatables, __index, __add, __tostring

-- setmetatable / getmetatable
local t = {10, 20, 30}
local mt = {}
setmetatable(t, mt)
local m = getmetatable(t)
print(m)

-- __index via table (fallback pour champs manquants)
local defaults = {x = 100, y = 200}
local obj = {}
local mt2 = {}
mt2.__index = defaults
setmetatable(obj, mt2)
print(obj.x)
print(obj.y)

-- Acces direct sans __index
obj.z = 300
print(obj.z)

-- rawget : acces brut sans passer par __index
local v = rawget(obj, 1)
print(v)

-- rawset : affectation brute
rawset(obj, 1, 42)
print(obj[1])

-- getmetatable retourne nil si pas de metatable
local plain = {1, 2, 3}
local pm = getmetatable(plain)
print(pm)

-- __index pour simuler un objet avec methodes
local Animal = {}
Animal.__index = Animal

function Animal.new(name)
  local self = {}
  self.name = name
  setmetatable(self, Animal)
  return self
end

function Animal.getName(self)
  return self.name
end

local cat = Animal.new("Felix")
print(cat.name)

-- Table avec metatable : longueur et acces
local t3 = {5, 10, 15}
print(#t3)
print(t3[2])
