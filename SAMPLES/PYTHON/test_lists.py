# test_lists.py - Test TODO 15: LISTES (list)
# Compile : PYTHON86 test_lists.py test_lists.asm

# Liste vide
a = []

# Liste literale
b = [10, 20, 30]

# Acces par index
x = b[0]
print(x)

y = b[2]
print(y)

# Index negatif
z = b[-1]
print(z)

# Affectation par index
b[1] = 99
print(b[1])

# len() sur liste
n = len(b)
print(n)

# append
b.append(40)
print(len(b))

# pop
v = b.pop()
print(v)

# Concatenation
c = [1, 2] + [3, 4]
print(len(c))

# Repetition
d = [0] * 3
print(len(d))

# Operateur in
if 20 in b:
    print(1)
if 999 in b:
    print(0)

# Slice
e = [10, 20, 30, 40, 50]
f = e[1:3]
print(len(f))
print(f[0])
