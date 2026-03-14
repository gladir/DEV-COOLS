-- test_tables.lua - Test des tables (TODO 15)
-- Verifie le code genere pour :
--   - Constructeur de table liste
--   - Constructeur de table record
--   - Constructeur mixte
--   - Acces par index t[i]
--   - Acces par champ t.x
--   - Affectation t[i] = v
--   - Affectation t.x = v
--   - Longueur #t
--   - table.insert
--   - table.remove
--   - table.sort

-- ---- Test 1 : table liste ----
local t1 = {10, 20, 30}
print(#t1)

-- ---- Test 2 : table record ----
local t2 = {x=1, y=2}
print(t2.x)

-- ---- Test 3 : acces par index ----
local t3 = {100, 200, 300}
print(t3[2])

-- ---- Test 4 : affectation index ----
local t4 = {5, 10, 15}
t4[2] = 99
print(t4[2])

-- ---- Test 5 : affectation champ ----
local t5 = {a=0}
t5.a = 42
print(t5.a)

-- ---- Test 6 : table.insert ----
local t6 = {1, 2, 3}
table.insert(t6, 4)
print(#t6)

-- ---- Test 7 : table.sort ----
local t7 = {30, 10, 20}
table.sort(t7)
print(t7[1])

-- ---- Test 8 : table vide ----
local t8 = {}
print(#t8)
