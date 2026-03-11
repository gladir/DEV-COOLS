// test_inherit.cpp - Test TODO 20: Heritage et Methodes Virtuelles
// Tests: inheritance, virtual methods, override, vtable dispatch,
//        base constructor call, pure virtual, polymorphism

// Base class with virtual method
class Animal {
public:
    virtual int speak() {
        return 0;
    }

    int legs;

    Animal() {
        legs = 4;
    }

    int getLegs() {
        return legs;
    }
};

// Derived class overriding virtual method
class Dog : public Animal {
public:
    Dog() {
        legs = 4;
    }

    int speak() {
        return 1;
    }
};

// Another derived class
class Cat : public Animal {
public:
    Cat() {
        legs = 4;
    }

    int speak() {
        return 2;
    }
};

// Simple inheritance without virtual methods
class Shape {
public:
    int width;
    int height;

    Shape() {
        width = 0;
        height = 0;
    }

    int area() {
        return width * height;
    }
};

class Rectangle : public Shape {
public:
    Rectangle() {
        width = 5;
        height = 3;
    }
};

// Inheritance with extra field
class ColorRect : public Shape {
public:
    int color;

    ColorRect() {
        width = 10;
        height = 2;
        color = 7;
    }
};

int main() {
    // Test 1: Simple inheritance - method from base
    Rectangle r;
    cout << r.area() << endl;

    // Test 2: Inherited fields
    cout << r.width << endl;
    cout << r.height << endl;

    // Test 3: Derived with extra field
    ColorRect cr;
    cout << cr.area() << endl;
    cout << cr.color << endl;

    // Test 4: Virtual method - direct call
    Dog d;
    cout << d.speak() << endl;
    cout << d.getLegs() << endl;

    // Test 5: Virtual method on another derived
    Cat c;
    cout << c.speak() << endl;

    // Test 6: Dynamic allocation with inheritance
    Dog *dp = new Dog();
    cout << dp->speak() << endl;
    cout << dp->getLegs() << endl;
    delete dp;

    return 0;
}
