-- test_scope.lua : test portee, pile et cadres (TODO 18)

-- Test 1 : do...end cree une portee locale
local a = 1
do
  local a = 2
  print(a)
end
print(a)

-- Test 2 : nettoyage de pile apres do...end
local b = 10
do
  local c = 20
  local d = 30
  print(c)
  print(d)
end
print(b)

-- Test 3 : do...end imbrique
do
  local x = 5
  do
    local y = 6
    print(x)
    print(y)
  end
  print(x)
end

-- Test 4 : fonction avec sauvegarde SI/DI
function compute(n)
  local r = n + 1
  return r
end
print(compute(10))

-- Test 5 : variable locale capturee (upvalue)
local val = 100
function show_val()
  print(val)
end
show_val()

-- Test 6 : portee dans boucle for
local sum = 0
for i = 1, 3 do
  local tmp = i
  sum = sum + tmp
end
print(sum)

-- Test 7 : do...end vide
do
end
print(42)
