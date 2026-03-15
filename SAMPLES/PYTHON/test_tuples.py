# test_tuples.py - Test TODO 19: TUPLES ET UNPACKING
# Compile : PYTHON86 test_tuples.py test_tuples.asm

# Tuple vide
a = ()

# Tuple literal
b = (10, 20, 30)

# Acces par index
x = b[0]
print(x)

y = b[2]
print(y)

# Index negatif
z = b[-1]
print(z)

# len() sur tuple
n = len(b)
print(n)

# Tuple singleton
s = (42,)
print(len(s))
print(s[0])

# Concatenation de tuples
c = (1, 2) + (3, 4)
print(len(c))
print(c[0])
print(c[3])

# Repetition de tuple
d = (7,) * 3
print(len(d))
print(d[0])

# Operateur in
if 20 in b:
    print(1)
if 999 in b:
    print(0)

# Unpacking
a, b, c = (100, 200, 300)
print(a)
print(b)
print(c)
