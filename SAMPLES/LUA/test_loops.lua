-- test_loops.lua - Test des boucles (TODO 14)
-- Verifie le code genere pour :
--   - while cond do stmts end
--   - repeat stmts until cond
--   - for i = start, stop [, step] do stmts end
--   - break dans une boucle
--   - goto / ::label::

-- ---- Test 1 : while simple ----
local i = 0
while i < 5 do
  i = i + 1
end
print(i)

-- ---- Test 2 : repeat simple ----
local j = 10
repeat
  j = j - 1
until j < 5
print(j)

-- ---- Test 3 : for numerique simple ----
local sum = 0
for k = 1, 5 do
  sum = sum + k
end
print(sum)

-- ---- Test 4 : for numerique avec step ----
local s2 = 0
for m = 0, 10, 2 do
  s2 = s2 + m
end
print(s2)

-- ---- Test 5 : for numerique avec step negatif ----
local s3 = 0
for n = 5, 1, -1 do
  s3 = s3 + n
end
print(s3)

-- ---- Test 6 : while avec break ----
local b = 0
while true do
  b = b + 1
  if b == 3 then
    break
  end
end
print(b)

-- ---- Test 7 : goto simple ----
local g = 0
g = 10
goto done
g = 99
::done::
print(g)

-- ---- Test 8 : boucles imbriquees ----
local total = 0
local a = 1
while a <= 3 do
  local c = 1
  while c <= 3 do
    total = total + 1
    c = c + 1
  end
  a = a + 1
end
print(total)
