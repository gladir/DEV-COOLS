# test_comprehensions.py - Test TODO 22: COMPREHENSIONS ET GENERATEURS
# Compile : PYTHON86 test_comprehensions.py test_comprehensions.asm

# List comprehension simple : [expr for var in range(n)]
a = [x for x in range(5)]
print(len(a))
print(a[0])
print(a[4])

# List comprehension avec expression
b = [x * 2 for x in range(4)]
print(len(b))
print(b[0])
print(b[1])
print(b[3])

# List comprehension avec filtre if
c = [x for x in range(10) if x > 6]
print(len(c))
print(c[0])
print(c[2])

# List comprehension avec range(a, b)
d = [x for x in range(3, 7)]
print(len(d))
print(d[0])
print(d[3])

# Dict comprehension simple
e = {x: x * 10 for x in range(3)}
print(len(e))
print(e[0])
print(e[2])
