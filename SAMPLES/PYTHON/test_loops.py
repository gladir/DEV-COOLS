# test_loops.py - Test TODO 14: BOUCLES while / for / break / continue
# Compile : PYTHON86 test_loops.py test_loops.asm

# Simple while
x = 5
while x > 0:
    print(x)
    x = x - 1

# While avec condition False immediate
y = 0
while y > 10:
    print("jamais")

# For range(n)
for i in range(5):
    print(i)

# For range(a, b)
for i in range(2, 6):
    print(i)

# For range(a, b, step)
for i in range(0, 10, 3):
    print(i)

# Break
for i in range(10):
    if i == 3:
        break
    print(i)

# Continue
for i in range(5):
    if i == 2:
        continue
    print(i)

# While avec else
n = 3
while n > 0:
    n = n - 1
print("fin boucle")

# Boucles imbriquees
for i in range(3):
    for j in range(3):
        print(i)
