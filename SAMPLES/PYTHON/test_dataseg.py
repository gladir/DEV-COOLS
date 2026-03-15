# test_dataseg.py - Test du segment de donnees et statiques (TODO 08)
# Compile : PYTHON86 test_dataseg.py test_dataseg.asm
# Verifie : variables globales (DK_WORD), chaines (DK_STR),
#           heap statique (_PY_HEAP, _PY_HEAPTOP)

# Variables globales (stockees en DATA comme DW)
x = 42
y = -7
z = 0

# Chaines litterales (stockees en DATA comme DB avec label _PYK_N)
greeting = "hello"
name = "world"
empty = ""

# Expressions entiers
a = 100 + 200
b = 10 * 5

# Booleens
flag = True
nope = False

# None
nothing = None
