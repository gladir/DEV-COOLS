-- test_if.lua : test TODO 13 - IF / ELSEIF / ELSE

-- if simple (condition vraie)
local x = 10
if x then
  print("x is truthy")
end

-- if avec condition fausse (nil)
if nil then
  print("should not print")
end

-- if/else simple
local y = 0
if y then
  print("y is truthy (0 is true in Lua!)")
else
  print("should not print")
end

-- if/elseif/else
local a = 5
if a == 10 then
  print("a is 10")
elseif a == 5 then
  print("a is 5")
else
  print("a is other")
end

-- if/elseif chaine sans else
local b = 3
if b == 1 then
  print("one")
elseif b == 2 then
  print("two")
elseif b == 3 then
  print("three")
end

-- if imbrique
local c = 7
if c > 0 then
  if c > 5 then
    print("c > 5")
  else
    print("c <= 5")
  end
end

-- false est faux en Lua
if false then
  print("should not print")
else
  print("false is falsy")
end

-- true est vrai en Lua
if true then
  print("true is truthy")
end

-- nombre non-nul : vrai en Lua
if 42 then
  print("42 is truthy")
end

-- Comparaison dans la condition
local d = 20
if d > 10 then
  print("d > 10")
end
