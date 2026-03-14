# test_dicts.py - Test TODO 16: DICTIONNAIRES (dict)
# Compile : PYTHON86 test_dicts.py test_dicts.asm

# Dict vide
a = {}

# Dict literal
b = {1: 10, 2: 20, 3: 30}

# len() sur dict
n = len(b)
print(n)

# Acces par cle
x = b[1]
print(x)

y = b[3]
print(y)

# Affectation par cle (mise a jour)
b[2] = 99
print(b[2])

# Affectation par cle (nouvelle cle)
b[4] = 40
print(len(b))

# d.get(key, default)
v = b.get(1, 0)
print(v)

w = b.get(999, -1)
print(w)

# key in d
if 1 in b:
    print(1)
if 999 in b:
    print(0)

# d.keys()
k = b.keys()
print(len(k))

# d.values()
vals = b.values()
print(len(vals))

# del d[key]
del b[4]
print(len(b))
