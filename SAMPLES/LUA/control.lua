-- control.lua : if/elseif, while, repeat/until, for numerique

-- if simple
local x = 10
if x > 5 then
  print("x > 5")
end

-- if/else
local y = 3
if y > 10 then
  print("grand")
else
  print("petit")
end

-- if/elseif/else
local grade = 75
if grade >= 90 then
  print("A")
elseif grade >= 80 then
  print("B")
elseif grade >= 70 then
  print("C")
elseif grade >= 60 then
  print("D")
else
  print("F")
end

-- if imbrique
local a = 5
local b = 10
if a > 0 then
  if b > a then
    print("b > a > 0")
  end
end

-- while
local i = 0
local sum = 0
while i < 10 do
  i = i + 1
  sum = sum + i
end
print(sum)

-- while avec break
local j = 0
while true do
  j = j + 1
  if j == 5 then
    break
  end
end
print(j)

-- repeat/until
local k = 10
repeat
  k = k - 2
until k <= 0
print(k)

-- for numerique (step implicite = 1)
local total = 0
for n = 1, 5 do
  total = total + n
end
print(total)

-- for numerique avec step
local evens = 0
for n = 2, 10, 2 do
  evens = evens + n
end
print(evens)

-- for numerique avec step negatif
local countdown = 0
for n = 5, 1, -1 do
  countdown = countdown + n
end
print(countdown)

-- boucles imbriquees
local count = 0
for i = 1, 3 do
  for j = 1, 3 do
    count = count + 1
  end
end
print(count)

-- goto et label
local v = 0
v = 42
goto skip
v = 0
::skip::
print(v)

-- do...end pour portee
do
  local tmp = 99
  print(tmp)
end
