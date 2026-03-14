-- test_io.lua : test TODO 12 - Entrees/Sorties (print, io)

-- print basique (deja teste dans TODO 10/11, rappel)
print(42)
print("hello")

-- io.write : ecriture sans retour a la ligne ni separateur
io.write("abc")
io.write("def")
io.write("\n")

-- io.write avec nombre
io.write(123)
io.write("\n")

-- io.write avec plusieurs arguments
io.write("x=", 10, " y=", 20)
io.write("\n")

-- tostring et tonumber (deja en TODO 10, rappel)
local s = tostring(99)
print(s)

local n = tonumber("42")
print(n)

-- print avec nil et boolean
print(nil)
print(true)
print(false)

-- io.write avec nil
io.write("done")
io.write("\n")
