-- test_functions.lua : test des fonctions et closures (TODO 17)

-- Test 1 : declaration de fonction globale simple
function greet()
  print("hello")
end
greet()

-- Test 2 : fonction avec parametres
function add(a, b)
  return a + b
end
local r = add(3, 4)
print(r)

-- Test 3 : fonction avec return sans valeur
function noop()
  return
end
noop()

-- Test 4 : local function
local function square(x)
  return x * x
end
print(square(5))

-- Test 5 : fonction anonyme comme valeur
local double = function(n)
  return n * 2
end
print(double(7))

-- Test 6 : fonction appelee plusieurs fois
function mul(a, b)
  return a * b
end
print(mul(3, 3))
print(mul(4, 5))

-- Test 7 : do ... end block
do
  local x = 99
  print(x)
end
