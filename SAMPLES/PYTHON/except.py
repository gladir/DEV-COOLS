# except.py - Exemple PYTHON86 : try/except/finally, raise
# Compile : PYTHON86.EXE SAMPLES\PYTHON\except.py except.asm

# Try / except simple
print("=== try / except ===")
try:
    x = 10
    print("Dans le try, x =", x)
except:
    print("Exception attrapee")

# Try avec raise
print()
print("=== raise ===")
try:
    print("Avant raise")
    raise 42
    print("Apres raise (jamais atteint)")
except:
    print("Exception attrapee apres raise")

# Try / except / else
print()
print("=== try / except / else ===")
try:
    y = 20
    print("try ok, y =", y)
except:
    print("exception")
else:
    print("else execute car pas d exception")

# Try / except / finally
print()
print("=== try / finally ===")
try:
    z = 30
    print("try, z =", z)
finally:
    print("finally execute toujours")

# Try / except / finally avec raise
print()
print("=== try / except / finally avec raise ===")
try:
    print("Avant raise dans try")
    raise 99
except:
    print("except : exception attrapee")
finally:
    print("finally : execute apres except")

# Fonction avec try/except
def safe_divide(a, b):
    try:
        if b == 0:
            raise 1
        return a
    except:
        print("Division par zero evitee")
        return 0

print()
print("=== Fonction avec try ===")
r = safe_divide(10, 2)
print("safe_divide(10, 2) =", r)
r = safe_divide(10, 0)
print("safe_divide(10, 0) =", r)

print()
print("Fin de except.py")
