# strings.py - Exemple PYTHON86 : operations sur chaines, find, upper, split
# Compile : PYTHON86.EXE SAMPLES\PYTHON\strings.py strings.asm

# Concatenation et repetition
print("=== Concatenation et repetition ===")
s1 = "Hello"
s2 = " World"
s3 = s1 + s2
print("concat :", s3)

sep = "-" * 30
print(sep)

# Longueur
print()
print("=== Longueur ===")
msg = "Bonjour"
print("len(Bonjour) =", len(msg))

# Indexation
print()
print("=== Indexation ===")
abc = "ABCDEF"
print("abc[0] =", abc[0])
print("abc[2] =", abc[2])
print("abc[5] =", abc[5])

# Slicing
print()
print("=== Slicing ===")
texte = "Hello World"
print("texte[0:5] =", texte[0:5])
print("texte[6:11] =", texte[6:11])

# Upper et lower
print()
print("=== Upper / Lower ===")
s = "Hello World"
print("upper :", s.upper())
print("lower :", s.lower())

# Strip
print()
print("=== Strip ===")
s = "  espaces  "
print("strip :", s.strip())

# Find
print()
print("=== Find ===")
s = "Hello World"
pos = s.find("World")
print("find(World) =", pos)
pos = s.find("xyz")
print("find(xyz) =", pos)

# Startswith / endswith
print()
print("=== Startswith / Endswith ===")
s = "Hello World"
if s.startswith("Hello"):
    print("Commence par Hello")
if s.endswith("World"):
    print("Termine par World")

# Replace
print()
print("=== Replace ===")
s = "Hello World"
s2 = s.replace("World", "Python")
print("replace :", s2)

# Operateur in
print()
print("=== Operateur in ===")
s = "Hello World"
if "World" in s:
    print("World trouve dans la chaine")
if "xyz" in s:
    print("xyz trouve")
else:
    print("xyz non trouve")

print()
print("Fin de strings.py")
