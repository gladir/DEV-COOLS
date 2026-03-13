# test_operators.py - Test des operateurs et precedence PYTHON86
# Compile : PYTHON86 test_operators.py test_operators.asm

# Arithmetique de base
a = 2 + 3
b = 10 - 4
c = 5 * 6
d = 20 // 4
e = 17 % 5
f = 2 ** 8

# Division flottante traitee comme division entiere
g = 15 / 4

# Operateurs unaires
h = -42
i = +7
j = ~0xFF
k = not True

# Operateurs bit a bit
l = 0xFF & 0x0F
m = 0xF0 | 0x0F
n = 0xFF ^ 0x0F
o = 1 << 4
p = 256 >> 3

# Comparaisons
q = 10 == 10
r = 10 != 5
s = 3 < 7
t = 3 <= 3
u = 9 > 2
v = 5 >= 5

# Logiques (court-circuit)
w = True and False
x = False or True
y = not False

# Precedence : ** avant *
z = 2 * 3 ** 2

# Precedence : * avant +
aa = 2 + 3 * 4

# Associativite droite de **
bb = 2 ** 3 ** 2

# Parentheses
cc = (2 + 3) * 4

# Combinaisons
dd = (10 - 3) * 2 + 1
ee = 1 + 2 * 3 - 4 // 2
ff = ~0 & 0xFF
gg = True and True or False

# Identite
hh = None is None
ii = 42 is not None

# Appartenance (stub)
jj = 1 in [1, 2, 3]
