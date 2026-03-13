/* test_if_else.c : test des instructions de controle if/else (TODO 13) */
#include <stdio.h>

int test_simple_if(int x) {
    int r = 0;
    if (x > 0)
        r = 1;
    return r;
}

int test_if_else(int x) {
    int r;
    if (x > 0)
        r = 1;
    else
        r = -1;
    return r;
}

int test_if_else_block(int x) {
    int r;
    if (x > 10) {
        r = 2;
    } else {
        r = -2;
    }
    return r;
}

int test_else_if(int x) {
    int r;
    if (x > 100) {
        r = 3;
    } else if (x > 10) {
        r = 2;
    } else if (x > 0) {
        r = 1;
    } else {
        r = 0;
    }
    return r;
}

int test_nested_if(int a, int b) {
    int r = 0;
    if (a > 0) {
        if (b > 0) {
            r = 1;
        } else {
            r = 2;
        }
    } else {
        if (b > 0) {
            r = 3;
        } else {
            r = 4;
        }
    }
    return r;
}

int test_if_with_expr(int x) {
    int r = 0;
    if (x == 42) {
        r = 100;
    }
    return r;
}

int test_compound_in_if(int x) {
    int a = 0;
    int b = 0;
    if (x > 0) {
        a = x + 1;
        b = x + 2;
    } else {
        a = 0;
        b = 0;
    }
    return a + b;
}

int test_empty_then(int x) {
    int r = 5;
    if (x > 0)
        ;
    else
        r = 0;
    return r;
}

int main(void) {
    int r;
    r = test_simple_if(1);
    r = test_simple_if(0);
    r = test_if_else(5);
    r = test_if_else(-3);
    r = test_if_else_block(20);
    r = test_if_else_block(5);
    r = test_else_if(200);
    r = test_else_if(50);
    r = test_else_if(5);
    r = test_else_if(-1);
    r = test_nested_if(1, 1);
    r = test_nested_if(1, -1);
    r = test_nested_if(-1, 1);
    r = test_nested_if(-1, -1);
    r = test_if_with_expr(42);
    r = test_if_with_expr(0);
    r = test_compound_in_if(10);
    r = test_compound_in_if(-5);
    r = test_empty_then(1);
    r = test_empty_then(-1);
    return 0;
}
