# test_if.py - Test TODO 13: IF / ELIF / ELSE
# Compile : PYTHON86 test_if.py test_if.asm

# Simple if
x = 10
if x > 5:
    print("x est grand")

# if-else
y = 3
if y > 5:
    print("y est grand")
else:
    print("y est petit")

# if-elif-else
z = 5
if z < 5:
    print("z est petit")
elif z == 5:
    print("z vaut cinq")
else:
    print("z est grand")

# if imbrique
a = 10
b = 20
if a > 5:
    if b > 15:
        print("les deux grands")

# Condition avec expression
if (x + y) > 10:
    print("somme grande")

# Expression ternaire
val = 1 if x > 5 else 0
print(val)

# Ternaire avec chaine
msg = "grand" if x > 5 else "petit"

# if avec pass
if x < 0:
    pass
else:
    print("x positif")

# elif multiple
n = 2
if n == 1:
    print("un")
elif n == 2:
    print("deux")
elif n == 3:
    print("trois")
else:
    print("autre")
