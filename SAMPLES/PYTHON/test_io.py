# test_io.py - Test TODO 12: ENTREES/SORTIES (BUILTINS print / input)
# Compile : PYTHON86 test_io.py test_io.asm

# print() sans argument : juste un saut de ligne
print()

# print avec un entier
print(42)

# print avec une chaine
print("hello world")

# print avec plusieurs arguments (sep = espace)
print(1, 2, 3)

# print avec un melange chaine et entier
print("valeur:", 100)

# print avec expression
x = 10
y = 20
print(x + y)

# print avec variable chaine
s = "bonjour"
print(s)

# print avec conversion str/int
n = 255
print("hex:", hex(n))
print("oct:", oct(n))
print("bin:", bin(n))

# input sans prompt
name = input()

# input avec prompt chaine
age = input("Quel age ? ")

# Conversion input -> int
val = int(input("Entrez un nombre : "))

# Chaine de caracteres avec len
msg = "Python86"
print("longueur:", len(msg))
