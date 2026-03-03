/* main.c - Test program using #include directive */

#include "test.h"

int main() {
    Point p;
    int result;
    
    p.x = 10;
    p.y = 20;
    
    result = multiply(p.x, p.y);
    
    if (result > MAX_SIZE) {
        return 1;
    }
    
    return 0;
}

int multiply(int a, int b) {
    return a * b;
}
