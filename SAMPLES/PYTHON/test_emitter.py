# test_emitter.py - Test de l emetteur de code ASM (TODO 07)
# Compile : PYTHON86 test_emitter.py test_emitter.asm
# Verifie : prologue/epilogue, point d entree, segment de donnees

# Variables globales (segment DATA)
x = 42
msg = "hello"

# Expressions avec emission ASM
y = x + 1
z = 10 - 3

# Booleens
flag = True

# None
n = None
