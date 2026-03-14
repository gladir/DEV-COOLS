# control.py - Exemple PYTHON86 : if/elif/else, while, for, break, continue
# Compile : PYTHON86.EXE SAMPLES\PYTHON\control.py control.asm

# --- if / elif / else ---
print("=== if / elif / else ===")
x = 42
if x > 100:
    print("x est grand")
elif x > 10:
    print("x est moyen")
else:
    print("x est petit")

# Test egalite
y = 0
if y == 0:
    print("y est zero")
else:
    print("y n est pas zero")

# --- while ---
print()
print("=== while ===")
i = 1
while i <= 5:
    print("i =", i)
    i = i + 1

# Somme avec while
s = 0
n = 1
while n <= 10:
    s = s + n
    n = n + 1
print("Somme 1..10 =", s)

# --- for / range ---
print()
print("=== for / range ===")
for j in range(5):
    print("j =", j)

# for avec bornes
print("Comptage 3 a 7 :")
for k in range(3, 8):
    print(k)

# --- break ---
print()
print("=== break ===")
for i in range(10):
    if i == 5:
        break
    print("i =", i)
print("Sorti a i = 5")

# --- continue ---
print()
print("=== continue ===")
for i in range(8):
    if i == 3:
        continue
    if i == 6:
        continue
    print("i =", i)

# --- boucles imbriquees ---
print()
print("=== Boucles imbriquees ===")
for a in range(3):
    for b in range(3):
        print(a, b)

print()
print("Fin de control.py")
