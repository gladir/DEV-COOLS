-- Test TODO 24 : Runtime minimal
-- Verifie que les routines runtime de base fonctionnent correctement

-- Test 1 : print() affiche une chaine avec retour a la ligne
print("hello")

-- Test 2 : print() affiche un nombre
print(42)

-- Test 3 : print() affiche nil
print(nil)

-- Test 4 : concatenation de chaines
local s = "abc" .. "def"
print(s)

-- Test 5 : longueur de chaine (#)
local n = #"hello"
print(n)

-- Test 6 : tostring() conversion
local t = tostring(123)
print(t)

-- Test 7 : tonumber() conversion
local v = tonumber("456")
print(v)

-- Test 8 : type() retourne le type
local ty = type(10)
print(ty)

-- Test 9 : math.abs() valeur absolue
local a = math.abs(-7)
print(a)

-- Test 10 : comparaison de chaines
local r = ("abc" == "abc")
print(r)

-- Test 11 : table.concat avec separateur
local t2 = {10, 20, 30}
local joined = table.concat(t2, ",")
print(joined)

-- Test 12 : string.sub extraction
local sub = string.sub("hello", 1, 3)
print(sub)
