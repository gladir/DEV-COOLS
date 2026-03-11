// test_class.cpp - Test TODO 19: Classes and Objects
// Tests: class declaration, fields, methods, constructor, destructor,
//        access levels, new/delete, this pointer, member access

// Simple class with public members
class Counter {
public:
    int value;

    Counter() {
        value = 0;
    }

    void increment() {
        value = value + 1;
    }

    int get() {
        return value;
    }
};

// Class with private field and public methods
class Point {
private:
    int x;
    int y;

public:
    Point() {
        x = 0;
        y = 0;
    }

    void set(int a, int b) {
        x = a;
        y = b;
    }

    int getX() {
        return x;
    }

    int getY() {
        return y;
    }
};

// Class with constructor that sets values
class Box {
public:
    int width;
    int height;

    Box() {
        width = 10;
        height = 20;
    }

    int area() {
        return width * height;
    }
};

int main() {
    // Test 1: class with constructor and methods
    Counter c;
    c.increment();
    c.increment();
    c.increment();
    cout << c.get() << endl;

    // Test 2: class with private fields
    Point p;
    p.set(5, 10);
    cout << p.getX() << endl;
    cout << p.getY() << endl;

    // Test 3: class with constructor init
    Box b;
    cout << b.width << endl;
    cout << b.height << endl;

    // Test 4: dynamic allocation with new
    Box *bp = new Box();
    cout << bp->width << endl;
    delete bp;

    return 0;
}
