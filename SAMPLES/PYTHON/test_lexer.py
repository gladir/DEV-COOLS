# Test du lexeur Python86
x = 42
y = 0xFF
z = 0b1010
w = 0o77
name = "hello"
msg = 'world'
pi = 3.14
big = 1_000_000

if x > 10:
    print(x)
    if y == 255:
        print(y)
else:
    print(0)

def add(a, b):
    return a + b

# Operateurs
result = x + y - z * w // 2
flags = x & y | z ^ w
shifted = x << 2
power = x ** 3

# Chaine triple
doc = """ceci est
une chaine multi-ligne"""

# Mots-cles
for i in range(10):
    if i == 5:
        break
    continue

while True:
    pass

class Foo:
    def __init__(self):
        self.val = None

    def get(self):
        return self.val

# Fin du test
