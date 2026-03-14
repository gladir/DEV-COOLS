/* classes.cpp - class, heritage, methodes virtuelles */

class Animal {
public:
    int age;
    Animal() {
        age = 0;
    }
    virtual int speak() {
        return 1;
    }
};

class Dog : public Animal {
public:
    int speak() {
        return 2;
    }
};

int main() {
    Dog d;
    d.age = 5;
    int s = d.speak();
    cout << d.age << endl;
    cout << s << endl;
    return 0;
}
