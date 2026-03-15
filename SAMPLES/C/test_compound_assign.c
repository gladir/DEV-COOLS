/* test_compound_assign.c : test des affectations composees (TODO 12) */
#include <stdio.h>

int test_compound_arith(void) {
    int x = 10;
    x += 5;
    x -= 3;
    x *= 2;
    x /= 4;
    x %= 3;
    return x;
}

int test_compound_bitwise(void) {
    int a = 0xFF;
    a &= 0x0F;
    a |= 0x30;
    a ^= 0x05;
    a <<= 2;
    a >>= 1;
    return a;
}

int test_post_increment(void) {
    int i = 0;
    i++;
    i++;
    i++;
    return i;
}

int test_post_decrement(void) {
    int j = 10;
    j--;
    j--;
    j--;
    return j;
}

int test_pre_increment(void) {
    int k = 0;
    ++k;
    ++k;
    return k;
}

int test_pre_decrement(void) {
    int m = 5;
    --m;
    --m;
    return m;
}

int test_deref_assign(void) {
    int val = 42;
    int *p;
    p = &val;
    *p = 100;
    return val;
}

int test_deref_compound(void) {
    int val = 10;
    int *p;
    p = &val;
    *p += 5;
    return val;
}

int test_mixed(void) {
    int a = 1;
    int b = 2;
    a += b;
    b *= a;
    a -= 1;
    b /= 2;
    return a + b;
}

int main(void) {
    int r;
    r = test_compound_arith();
    r = test_compound_bitwise();
    r = test_post_increment();
    r = test_post_decrement();
    r = test_pre_increment();
    r = test_pre_decrement();
    r = test_deref_assign();
    r = test_deref_compound();
    r = test_mixed();
    return 0;
}
