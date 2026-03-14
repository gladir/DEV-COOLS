-- Test TODO 23 : Coroutines (basiques)

-- Test 1 : coroutine.create() cree une coroutine
local function gen()
  coroutine.yield(10)
  coroutine.yield(20)
  return 30
end
local co = coroutine.create(gen)
print(co)

-- Test 2 : coroutine.status() avant resume
local st = coroutine.status(co)
print(st)

-- Test 3 : coroutine.resume() premier yield
local ok = coroutine.resume(co)
print(ok)

-- Test 4 : coroutine.resume() deuxieme yield
local ok2 = coroutine.resume(co)
print(ok2)

-- Test 5 : coroutine.resume() retour final
local ok3 = coroutine.resume(co)
print(ok3)

-- Test 6 : coroutine.status() apres fin -> dead
local st2 = coroutine.status(co)
print(st2)

-- Test 7 : coroutine.resume() sur dead -> false
local ok4 = coroutine.resume(co)
print(ok4)

-- Test 8 : coroutine.wrap() cree un handle simplifie
local function counter()
  coroutine.yield(100)
  return 200
end
local w = coroutine.wrap(counter)
print(w)

-- Test 9 : coroutine.isyieldable() depuis le main
local iy = coroutine.isyieldable()
print(iy)
