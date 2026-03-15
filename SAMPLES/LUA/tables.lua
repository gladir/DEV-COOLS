-- tables.lua : constructeurs, acces, table.insert/sort/concat

-- Table liste simple
local t1 = {10, 20, 30}
print(#t1)
print(t1[1])
print(t1[2])
print(t1[3])

-- Table record (cle = valeur)
local t2 = {x = 100, y = 200}
print(t2.x)
print(t2.y)

-- Table vide
local t3 = {}
print(#t3)

-- Affectation par index
t3[1] = 42
t3[2] = 84
print(t3[1])
print(t3[2])
print(#t3)

-- Affectation par champ
local obj = {}
obj.name = "lua"
print(obj.name)

-- table.insert
local t4 = {1, 2, 3}
table.insert(t4, 4)
print(#t4)
print(t4[4])

-- table.remove
table.remove(t4, 1)
print(t4[1])

-- table.sort
local t5 = {30, 10, 50, 20, 40}
table.sort(t5)
print(t5[1])
print(t5[2])
print(t5[3])

-- table.concat avec separateur
local t6 = {10, 20, 30}
local joined = table.concat(t6, "-")
print(joined)

-- Longueur de table
local t7 = {5, 10, 15, 20}
print(#t7)

-- Table imbriquee
local matrix = {{1, 2}, {3, 4}}
print(matrix[1][1])
print(matrix[2][2])
