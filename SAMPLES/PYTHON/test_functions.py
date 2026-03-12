# test_functions.py - Test TODO 17: FONCTIONS (def) ET RETURN
# Compile : PYTHON86 test_functions.py test_functions.asm

# Fonction simple sans parametre
def hello():
    print(42)

hello()

# Fonction avec return
def double(x):
    return x + x

y = double(5)
print(y)

# Fonction avec plusieurs parametres
def add(a, b):
    return a + b

z = add(3, 7)
print(z)

# Recursion
def fact(n):
    if n <= 1:
        return 1
    return n * fact(n - 1)

r = fact(5)
print(r)

# Fonction sans return explicite
def noop():
    pass

noop()
