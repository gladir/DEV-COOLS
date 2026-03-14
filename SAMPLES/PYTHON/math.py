# math.py - Exemple PYTHON86 : operateurs, fonctions, recursion, return
# Compile : PYTHON86.EXE SAMPLES\PYTHON\math.py math.asm

# Fonctions arithmetiques simples
def add(a, b):
    return a + b

def sub(a, b):
    return a - b

def mul(a, b):
    return a * b

# Fonction puissance
def power(base, exp):
    return base ** exp

# Factorielle recursive
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

# Fibonacci recursif
def fibonacci(n):
    if n <= 0:
        return 0
    if n == 1:
        return 1
    return fibonacci(n - 1) + fibonacci(n - 2)

# Valeur absolue
def abs_val(x):
    if x < 0:
        return -x
    return x

# Maximum de deux valeurs
def max_val(a, b):
    if a > b:
        return a
    return b

# Minimum de deux valeurs
def min_val(a, b):
    if a < b:
        return a
    return b

# Tests
print("=== Operateurs de base ===")
print("add(10, 32) =", add(10, 32))
print("sub(50, 8) =", sub(50, 8))
print("mul(6, 7) =", mul(6, 7))

print()
print("=== Puissance ===")
print("power(2, 10) =", power(2, 10))
print("power(3, 4) =", power(3, 4))

print()
print("=== Factorielle ===")
print("factorial(1) =", factorial(1))
print("factorial(5) =", factorial(5))
print("factorial(7) =", factorial(7))

print()
print("=== Fibonacci ===")
print("fibonacci(0) =", fibonacci(0))
print("fibonacci(1) =", fibonacci(1))
print("fibonacci(6) =", fibonacci(6))
print("fibonacci(10) =", fibonacci(10))

print()
print("=== Abs / Max / Min ===")
print("abs_val(-42) =", abs_val(-42))
print("abs_val(7) =", abs_val(7))
print("max_val(10, 20) =", max_val(10, 20))
print("min_val(10, 20) =", min_val(10, 20))

print()
print("Fin de math.py")
