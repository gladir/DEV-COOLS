/* hello.cpp - Variables, constantes, chaines, cout */
#include <iostream>

const int MAX = 10;

int main() {
    int x = 42;
    int y = 100;
    const char* msg = "Hello, World!";

    cout << msg << endl;
    cout << "x = " << x << endl;
    cout << "y = " << y << endl;

    int sum = x + y;
    cout << "sum = " << sum << endl;

    return 0;
}
