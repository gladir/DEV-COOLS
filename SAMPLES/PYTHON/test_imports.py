# test_imports.py - Tests TODO 23 : Modules et Import (simplifie)

# Test 1 : import math (fonctions builtins)
import math
x = math.abs(-42)
print(x)

# Test 2 : from math import pow
from math import abs, pow, min, max
y = abs(-10)
print(y)
z = pow(2, 8)
print(z)
w = min(3, 7)
print(w)
v = max(3, 7)
print(v)

# Test 3 : import sys
import sys

# Test 4 : from sys import exit
from sys import exit

# Test 5 : import multiple
a = 100
print(a)
