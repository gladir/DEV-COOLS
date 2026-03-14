-- test_multiret.lua : test retours multiples et varargs (TODO 21)

-- Test 1 : retour simple (CX = 1)
function single()
  return 42
end
print(single())

-- Test 2 : retour multiple (return a, b, c)
function multi()
  return 10, 20, 30
end
local a = multi()
print(a)

-- Test 3 : retour sans valeur (CX = 0)
function noret()
  return
end
local b = noret()
print(b)

-- Test 4 : select('#', ...) et select(n, ...)
function vfunc(...)
  local n = select('#', ...)
  print(n)
  local v = select(1, ...)
  print(v)
end
vfunc(100, 200, 300)

-- Test 5 : fonction variadique avec params nommes
function vfunc2(a, b, ...)
  print(a)
  print(b)
end
vfunc2(5, 6, 7, 8)

-- Test 6 : retour multiple simple
function pair()
  return 1, 2
end
print(pair())
