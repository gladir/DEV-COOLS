# test_strings.py - Test TODO 20: CHAINES (str) OPERATIONS AVANCEES
# Compile : PYTHON86 test_strings.py test_strings.asm

# Concatenation
a = "hello" + " " + "world"
print(a)

# Repetition
b = "ab" * 3
print(b)

# Longueur
n = len("hello")
print(n)

# Index positif
s = "abcdef"
c = s[0]
print(c)

# Index negatif
d = s[-1]
print(d)

# Slice
e = s[1:4]
print(e)

# upper / lower
f = "hello"
g = f.upper()
print(g)

h = "WORLD"
i = h.lower()
print(i)

# strip
j = "  hi  "
k = j.strip()
print(k)

# find
s2 = "hello world"
idx = s2.find("world")
print(idx)

idx2 = s2.find("xyz")
print(idx2)

# startswith / endswith
print(s2.startswith("hello"))
print(s2.endswith("world"))
print(s2.startswith("world"))

# replace
r = s2.replace("world", "python")
print(r)

# count
s3 = "abcabcabc"
print(s3.count("abc"))

# in operator
if "lo" in "hello":
    print(1)
if "xyz" in "hello":
    print(0)

# chr / ord (deja implementes, mais testons)
x = chr(65)
print(x)
y = ord("A")
print(y)
