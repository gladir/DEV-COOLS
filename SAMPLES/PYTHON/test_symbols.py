# test_symbols.py - Test de la table des symboles PYTHON86
# Compile : PYTHON86 test_symbols.py test_symbols.asm

# Variables globales
x = 10
y = 20
z = x + y

# Re-utilisation de variable existante
x = 42
result = x * 2

# Appels de builtins (stubs)
print(x)
n = len("hello")
s = str(42)
v = abs(-5)

# Instruction global
global total
total = 100

# Instruction nonlocal (stub pour portees futures)
# nonlocal sera utile dans les fonctions imbriquees

# Variables avec noms longs
my_variable = 1
another_var = 2
combined = my_variable + another_var

# Variables multiples sur plusieurs lignes
a = 1
b = 2
c = 3
d = a + b + c
