# hello.py - Exemple PYTHON86 : print, variables, chaines, entiers
# Compile : PYTHON86.EXE SAMPLES\PYTHON\hello.py hello.asm

# Affichage simple
print("Bonjour de PYTHON86 !")
print("Compilateur Python -> 8086")
print()

# Variables entieres
x = 42
y = 8
print("x =", x)
print("y =", y)

# Arithmetique
z = x + y
print("x + y =", z)
z = x - y
print("x - y =", z)
z = x * y
print("x * y =", z)

# Variables chaines
nom = "PYTHON86"
version = "1.0"
print("Nom :", nom)
print("Version :", version)

# Concatenation de chaines
msg = "Hello" + " " + "World"
print(msg)

# Repetition de chaines
sep = "=-" * 20
print(sep)

# Entiers negatifs
n = -7
print("n =", n)

# Expressions complexes
resultat = (x + y) * 2 - 10
print("(x + y) * 2 - 10 =", resultat)

print()
print("Fin de hello.py")
