-- closures.lua : fonctions anonymes, closures, upvalues

-- Fonction anonyme assignee a une variable
local double = function(n)
  return n * 2
end
print(double(5))
print(double(21))

-- Closure : capture de variable locale
local count = 0
function increment()
  count = count + 1
  return count
end
print(increment())
print(increment())
print(increment())

-- Closure comme compteur
local val = 100
local function get_val()
  return val
end
print(get_val())
val = 200
print(get_val())

-- Fonction qui retourne une fonction
function make_adder(n)
  return function(x)
    return x + n
  end
end
local add5 = make_adder(5)
local add10 = make_adder(10)
print(add5(3))
print(add10(3))

-- Fonction locale recursive
local function countdown(n)
  if n <= 0 then
    return 0
  end
  return n + countdown(n - 1)
end
print(countdown(5))

-- Passage de fonction comme argument
function apply(f, x)
  return f(x)
end
local result = apply(double, 7)
print(result)

-- do...end avec closure
local outer = 10
do
  local inner = 20
  function show()
    print(outer)
    print(inner)
  end
end
show()
