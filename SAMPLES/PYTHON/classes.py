# classes.py - Exemple PYTHON86 : class, __init__, methodes, heritage
# Compile : PYTHON86.EXE SAMPLES\PYTHON\classes.py classes.asm

# Classe simple
class Counter:
    def __init__(self):
        self.count = 0

    def increment(self):
        self.count = self.count + 1

    def get(self):
        return self.count

print("=== Counter ===")
c = Counter()
print("Initial :", c.get())
c.increment()
c.increment()
c.increment()
print("Apres 3 increments :", c.get())

# Classe avec parametres
class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def display(self):
        print("Point(", self.x, ",", self.y, ")")

    def translate(self, dx, dy):
        self.x = self.x + dx
        self.y = self.y + dy

print()
print("=== Point ===")
p = Point(3, 4)
p.display()
p.translate(10, 20)
p.display()

# Heritage
class Animal:
    def __init__(self, nom):
        self.nom = nom

    def parler(self):
        print(self.nom, "fait du bruit")

class Chien(Animal):
    def __init__(self, nom):
        self.nom = nom

    def parler(self):
        print(self.nom, "dit Wouf!")

class Chat(Animal):
    def __init__(self, nom):
        self.nom = nom

    def parler(self):
        print(self.nom, "dit Miaou!")

print()
print("=== Heritage ===")
a = Animal("GenericAnimal")
a.parler()

d = Chien("Rex")
d.parler()

c = Chat("Felix")
c.parler()

# isinstance
print()
print("=== isinstance ===")
if isinstance(d, Chien):
    print("d est un Chien")
if isinstance(d, Animal):
    print("d est un Animal")

print()
print("Fin de classes.py")
