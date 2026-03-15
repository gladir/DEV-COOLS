-- errors.lua : pcall, error, xpcall, assert

-- assert avec valeur vraie
local x = 42
assert(x)
print(x)

-- assert avec message optionnel
assert(1, "ne devrait pas apparaitre")
print(1)

-- pcall avec fonction qui reussit
local function ok_func()
  return 42
end
local status = pcall(ok_func)
print(status)

-- pcall avec fonction qui echoue
local function bad_func()
  error("test error")
end
local status2 = pcall(bad_func)
print(status2)

-- pcall avec arguments
local function add(a, b)
  return a + b
end
local status3 = pcall(add, 10, 20)
print(status3)

-- xpcall avec handler
local function err_handler(msg)
  return msg
end
local function bad2()
  error("xpcall error")
end
local status4 = xpcall(bad2, err_handler)
print(status4)

-- xpcall avec succes
local function good()
  return 99
end
local status5 = xpcall(good, err_handler)
print(status5)

-- error avec level optionnel
local function bad3()
  error("level error", 2)
end
local status6 = pcall(bad3)
print(status6)

-- assert avec false
local status7 = pcall(function()
  assert(false, "assertion failed")
end)
print(status7)
