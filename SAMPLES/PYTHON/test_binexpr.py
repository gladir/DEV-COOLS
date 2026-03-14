# test_binexpr.py - Test TODO 11: EXPRESSIONS BINAIRES
# Compile : PYTHON86 test_binexpr.py test_binexpr.asm

# Arithmetique entiere : +, -, *, //, %
a = 10 + 5
b = 10 - 3
c = 4 * 7
d = 20 // 3
e = 17 % 5

# Puissance **
f = 2 ** 10
g = 3 ** 0

# Operateurs bit a bit : &, |, ^, <<, >>
h = 0xFF & 0x0F
i = 0xF0 | 0x0F
j = 0xFF ^ 0x0F
k = 1 << 8
l = 256 >> 4

# Comparaisons entieres : ==, !=, <, <=, >, >=
m = 10 == 10
n = 10 != 5
o = 3 < 7
p = 7 <= 7
q = 9 > 2
r = 5 >= 5

# Logique court-circuit : and, or
s = True and True
t = True and False
u = False or True
v = False or False

# Logique not (unaire)
w = not False
x = not True

# Concatenation de chaines
s1 = "hello" + " " + "world"

# Repetition de chaine
s2 = "ab" * 3

# Comparaison de chaines
c1 = "abc" == "abc"
c2 = "abc" != "def"
c3 = "abc" < "def"
c4 = "xyz" > "abc"
c5 = "abc" <= "abc"
c6 = "abc" >= "abc"

# Operateur in / not in (listes)
r1 = 1 in [1, 2, 3]
r2 = 5 not in [1, 2, 3]

# Identite is / is not
r3 = None is None
r4 = 42 is not None

# Combinaisons de precedence
z1 = 2 + 3 * 4
z2 = (2 + 3) * 4
z3 = 2 ** 3 ** 2
z4 = 10 - 3 * 2 + 1

# Expressions avec variables
x1 = 10
x2 = 20
x3 = x1 + x2
x4 = x1 * x2
x5 = x2 // x1
x6 = x1 == x2
x7 = x1 < x2
