# dicts.py - Exemple PYTHON86 : dictionnaires, acces, keys, values, del
# Compile : PYTHON86.EXE SAMPLES\PYTHON\dicts.py dicts.asm

# Creation de dictionnaires
print("=== Creation ===")
vide = {}
print("Dict vide, len =", len(vide))

ages = {"alice": 30, "bob": 25, "charlie": 35}
print("ages =", ages)
print("len(ages) =", len(ages))

# Acces par cle
print()
print("=== Acces ===")
print("ages[alice] =", ages["alice"])
print("ages[bob] =", ages["bob"])

# Modification
print()
print("=== Modification ===")
ages["bob"] = 26
print("Apres ages[bob] = 26 :", ages)

# Ajout de cle
ages["dave"] = 40
print("Apres ajout dave :", ages)
print("len =", len(ages))

# Methode get avec defaut
print()
print("=== Get ===")
v = ages.get("alice", 0)
print("get(alice, 0) =", v)
v = ages.get("eve", -1)
print("get(eve, -1) =", v)

# Operateur in (sur les cles)
print()
print("=== Operateur in ===")
if "charlie" in ages:
    print("charlie est dans ages")
if "eve" in ages:
    print("eve est dans ages")
else:
    print("eve n est pas dans ages")

# Keys et values
print()
print("=== Keys / Values ===")
k = ages.keys()
print("keys =", k)
v = ages.values()
print("values =", v)

# Del
print()
print("=== Del ===")
del ages["dave"]
print("Apres del dave :", ages)
print("len =", len(ages))

print()
print("Fin de dicts.py")
