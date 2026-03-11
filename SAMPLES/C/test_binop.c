/* test_binop.c : test des operateurs binaires et precedence (TODO 11) */
#include <stdio.h>

int test_arith(void) {
    int a = 10;
    int b = 3;
    int c;
    c = a + b;
    c = a - b;
    c = a * b;
    c = a / b;
    c = a % b;
    return c;
}

int test_compare(void) {
    int a = 5;
    int b = 10;
    int r;
    r = a == b;
    r = a != b;
    r = a < b;
    r = a <= b;
    r = a > b;
    r = a >= b;
    return r;
}

int test_bitwise(void) {
    int a = 0xFF;
    int b = 0x0F;
    int c;
    c = a & b;
    c = a | b;
    c = a ^ b;
    c = a << 4;
    c = a >> 4;
    return c;
}

int test_logic(void) {
    int a = 1;
    int b = 0;
    int r;
    r = a && b;
    r = a || b;
    r = !a;
    return r;
}

int test_ternary(void) {
    int a = 5;
    int r;
    r = a > 0 ? 1 : 0;
    return r;
}

int test_precedence(void) {
    int r;
    r = 2 + 3 * 4;
    r = 10 - 2 * 3;
    r = 1 + 2 > 3 - 1;
    return r;
}

int main(void) {
    int r;
    r = test_arith();
    r = test_compare();
    r = test_bitwise();
    r = test_logic();
    r = test_ternary();
    r = test_precedence();
    return 0;
}
