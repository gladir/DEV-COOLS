-- test_variables.lua : test TODO 09 - Variables et affectations

-- Variable globale simple
x = 42

-- Variable globale avec expression
y = 10 + 5

-- Declaration locale simple
local a = 100

-- Declaration locale sans init (nil)
local b

-- Declaration locale multiple
local c, d, e = 1, 2, 3

-- Affectation multiple globale
p, q = 7, 8

-- Affectation avec moins de valeurs que de noms (nil padding)
local f, g = 99

-- Affectation avec plus de valeurs que de noms (extras ignores)
local h = 10, 20, 30

-- Reassignation d une locale
a = a + 1

-- Reassignation d une globale
x = x + y
