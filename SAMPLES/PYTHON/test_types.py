# test_types.py - Test du systeme de types dynamique (TODO 06)
# Compile : PYTHON86 test_types.py test_types.asm

# Entiers : type int
x = 42
y = -10
z = 0xFF

# Booleens : type bool
b1 = True
b2 = False

# Chaines : type str
s1 = "hello"
s2 = 'world'

# None : type NoneType
n = None

# Expressions avec types deduits
a = 3 + 4
c = True and False
d = "abc" + "def"

# Appels de builtins de type
t = type(x)
check = isinstance(x, int)

# Verification de type
i = int(42)
s = str("test")
bl = bool(True)
