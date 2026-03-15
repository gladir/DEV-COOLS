-- Test TODO 22 : Gestion d'erreurs (pcall, error, xpcall, assert)

-- Test 1 : error() sans pcall -> termine le programme
-- (on ne peut pas tester ca directement car ca sort du programme)

-- Test 2 : assert() avec valeur vraie
local x = 42
assert(x)
print(x)

-- Test 3 : assert() avec message optionnel
assert(1, "ce message ne devrait pas apparaitre")
print(1)

-- Test 4 : pcall() avec fonction qui reussit
local function ok_func()
  return 42
end
local status = pcall(ok_func)
print(status)

-- Test 5 : pcall() avec fonction qui echoue
local function bad_func()
  error("test error")
end
local status2 = pcall(bad_func)
print(status2)

-- Test 6 : pcall() avec arguments
local function add(a, b)
  return a + b
end
local status3 = pcall(add, 10, 20)
print(status3)

-- Test 7 : xpcall() avec handler de message
local function err_handler(msg)
  return msg
end
local function bad2()
  error("xpcall error")
end
local status4 = xpcall(bad2, err_handler)
print(status4)

-- Test 8 : xpcall() avec succes
local function good()
  return 99
end
local status5 = xpcall(good, err_handler)
print(status5)

-- Test 9 : error() avec level optionnel (ignore)
local function bad3()
  error("level error", 2)
end
local status6 = pcall(bad3)
print(status6)
