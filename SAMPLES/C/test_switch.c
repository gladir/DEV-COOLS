/* test_switch.c : test du switch/case/default (TODO 15) */
#include <stdio.h>

int test_switch_basic(int x) {
    int r = 0;
    switch (x) {
        case 1:
            r = 10;
            break;
        case 2:
            r = 20;
            break;
        case 3:
            r = 30;
            break;
        default:
            r = 99;
            break;
    }
    return r;
}

int test_switch_default(int x) {
    int r = 0;
    switch (x) {
        case 10:
            r = 1;
            break;
        default:
            r = 42;
            break;
    }
    return r;
}

int test_switch_fallthrough(int x) {
    int r = 0;
    switch (x) {
        case 1:
        case 2:
        case 3:
            r = 100;
            break;
        default:
            r = 0;
            break;
    }
    return r;
}

int test_switch_no_default(int x) {
    int r = 5;
    switch (x) {
        case 1:
            r = 11;
            break;
        case 2:
            r = 22;
            break;
    }
    return r;
}

int test_switch_negative(int x) {
    int r = 0;
    switch (x) {
        case -1:
            r = 1;
            break;
        case 0:
            r = 2;
            break;
        case 1:
            r = 3;
            break;
    }
    return r;
}

int test_switch_in_loop(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        switch (i) {
            case 0:
                s = s + 1;
                break;
            case 1:
                s = s + 10;
                break;
            case 2:
                s = s + 100;
                break;
            default:
                s = s + 1000;
                break;
        }
    }
    return s;
}

int test_switch_char(int c) {
    int r = 0;
    switch (c) {
        case 65:
            r = 1;
            break;
        case 66:
            r = 2;
            break;
        default:
            r = 0;
            break;
    }
    return r;
}

int main(void) {
    int r;
    r = test_switch_basic(1);
    r = test_switch_basic(2);
    r = test_switch_basic(3);
    r = test_switch_basic(99);
    r = test_switch_default(10);
    r = test_switch_default(0);
    r = test_switch_fallthrough(1);
    r = test_switch_fallthrough(2);
    r = test_switch_fallthrough(3);
    r = test_switch_fallthrough(99);
    r = test_switch_no_default(1);
    r = test_switch_no_default(2);
    r = test_switch_no_default(99);
    r = test_switch_negative(-1);
    r = test_switch_negative(0);
    r = test_switch_negative(1);
    r = test_switch_in_loop(5);
    r = test_switch_char(65);
    r = test_switch_char(66);
    r = test_switch_char(67);
    return 0;
}
