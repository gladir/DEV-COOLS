# test_exceptions.py - Test TODO 21: GESTION DES EXCEPTIONS
# Compile : PYTHON86 test_exceptions.py test_exceptions.asm

# try/except simple
try:
    x = 10
    print(x)
except:
    print(0)

# try/except avec raise
try:
    raise 42
except:
    print(1)

# try/except/finally
try:
    y = 20
    print(y)
except:
    print(0)
finally:
    print(99)

# try avec raise et finally
try:
    raise 7
except:
    print(2)
finally:
    print(88)

# try/except avec type et as
try:
    raise 55
except Exception as e:
    print(e)

# raise sans expression dans try
try:
    raise
except:
    print(3)
