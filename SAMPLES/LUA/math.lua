-- math.lua : fonctions, recursion, return, math.abs/sqrt

-- Fonction simple avec return
function double(n)
  return n * 2
end
print(double(5))
print(double(21))

-- Recursion : factorielle
function fact(n)
  if n <= 1 then
    return 1
  end
  return n * fact(n - 1)
end
print(fact(5))
print(fact(1))
print(fact(0))

-- Recursion : fibonacci
function fib(n)
  if n <= 1 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end
print(fib(0))
print(fib(1))
print(fib(6))

-- math.abs
print(math.abs(-7))
print(math.abs(3))
print(math.abs(0))

-- math.max / math.min
print(math.max(3, 7))
print(math.min(3, 7))

-- math.floor / math.ceil
print(math.floor(10))
print(math.ceil(10))

-- math.sqrt (entiere)
print(math.sqrt(25))
print(math.sqrt(100))

-- Fonction avec parametres multiples
function add3(a, b, c)
  return a + b + c
end
print(add3(1, 2, 3))

-- Fonction locale
local function square(x)
  return x * x
end
print(square(4))
print(square(9))

-- Puissance (operateur ^)
local p = 2 ^ 10
print(p)

-- Modulo
local m = 17 % 5
print(m)
