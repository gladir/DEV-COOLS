# test_runtime.py - Tests TODO 24 : Runtime Minimal
# Verifie que les routines runtime de base fonctionnent correctement

# Test 1 : print entier (NUMTOSTR + PRINTSTR + NEWLINE)
x = 42
print(x)

# Test 2 : print chaine (PRINTSTR + NEWLINE)
msg = "Hello Runtime"
print(msg)

# Test 3 : concatenation de chaines (CONCAT)
a = "Hello"
b = " World"
c = a + b
print(c)

# Test 4 : comparaison de chaines (STRCMP)
s1 = "abc"
s2 = "abc"
if s1 == s2:
    print(1)

# Test 5 : repetition de chaine (STRMUL)
r = "ab" * 3
print(r)

# Test 6 : puissance entiere (POWER)
p = 2 ** 10
print(p)

# Test 7 : longueur de chaine (STRLEN / LEN)
n = len("hello")
print(n)

# Test 8 : conversion entier -> chaine (INTTOSTR)
v = str(123)
print(v)

# Test 9 : conversion chaine -> entier (STRTONUM)
w = int("456")
print(w)

# Test 10 : appartenance dans une liste (CONTAINS)
lst = [10, 20, 30]
if 20 in lst:
    print(1)

# Test 11 : allocation objet sur le heap (OBJNEW via class)
class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

pt = Point(3, 4)
print(pt.x)
print(pt.y)

# Test 12 : operations sur listes (LISTAPPEND)
items = [1, 2, 3]
items.append(4)
print(len(items))
