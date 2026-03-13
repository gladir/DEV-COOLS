# lists.py - Exemple PYTHON86 : listes, append, pop, index, slice, in
# Compile : PYTHON86.EXE SAMPLES\PYTHON\lists.py lists.asm

# Creation de listes
print("=== Creation ===")
vide = []
print("Liste vide, len =", len(vide))

nums = [10, 20, 30, 40, 50]
print("nums =", nums)
print("len(nums) =", len(nums))

# Acces par index
print()
print("=== Index ===")
print("nums[0] =", nums[0])
print("nums[2] =", nums[2])
print("nums[4] =", nums[4])

# Modification par index
nums[1] = 25
print("Apres nums[1] = 25 :", nums)

# Append
print()
print("=== Append ===")
nums.append(60)
print("Apres append(60) :", nums)
print("len =", len(nums))

# Pop
print()
print("=== Pop ===")
val = nums.pop()
print("pop() =", val)
print("Apres pop :", nums)

# Operateur in
print()
print("=== Operateur in ===")
if 30 in nums:
    print("30 est dans nums")
if 99 in nums:
    print("99 est dans nums")
else:
    print("99 n est pas dans nums")

# Concatenation de listes
print()
print("=== Concatenation ===")
a = [1, 2, 3]
b = [4, 5, 6]
c = a + b
print("a + b =", c)

# Repetition de liste
print()
print("=== Repetition ===")
r = [0] * 5
print("[0] * 5 =", r)

# Iteration sur une liste
print()
print("=== Iteration ===")
fruits = [10, 20, 30]
for f in fruits:
    print("elem =", f)

# Construction dynamique
print()
print("=== Construction dynamique ===")
result = []
for i in range(5):
    result.append(i * i)
print("Carres :", result)

print()
print("Fin de lists.py")
