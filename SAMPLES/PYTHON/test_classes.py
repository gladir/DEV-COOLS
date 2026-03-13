# Test TODO 18 : Classes (class) et objets

class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def get_x(self):
        return self.x

    def get_y(self):
        return self.y

    def sum(self):
        return self.x + self.y

p = Point(3, 4)
print(p.get_x())
print(p.get_y())
print(p.sum())

class Animal:
    def __init__(self, name):
        self.name = name
        self.sound = 0

    def speak(self):
        return self.sound

class Dog(Animal):
    def __init__(self, name):
        self.name = name
        self.sound = 42

d = Dog("Rex")
print(d.speak())
