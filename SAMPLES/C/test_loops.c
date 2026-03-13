/* test_loops.c : test des boucles for/while/do-while (TODO 14) */
#include <stdio.h>

int test_while_simple(int n) {
    int s = 0;
    int i = 1;
    while (i <= n) {
        s = s + i;
        i++;
    }
    return s;
}

int test_while_zero(void) {
    int s = 0;
    int i = 0;
    while (i > 0) {
        s = s + i;
        i--;
    }
    return s;
}

int test_do_while(int n) {
    int s = 0;
    int i = 1;
    do {
        s = s + i;
        i++;
    } while (i <= n);
    return s;
}

int test_for_simple(int n) {
    int s = 0;
    int i;
    for (i = 1; i <= n; i++) {
        s = s + i;
    }
    return s;
}

int test_for_decl(int n) {
    int s = 0;
    int i;
    for (int i = 0; i < n; i++) {
        s = s + 1;
    }
    return s;
}

int test_for_compound_incr(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i += 2) {
        s = s + 1;
    }
    return s;
}

int test_for_break(int n) {
    int s = 0;
    int i;
    for (i = 0; i < 100; i++) {
        if (i >= n)
            break;
        s = s + 1;
    }
    return s;
}

int test_while_break(int n) {
    int s = 0;
    int i = 0;
    while (1) {
        if (i >= n)
            break;
        s = s + 1;
        i++;
    }
    return s;
}

int test_for_continue(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        if (i == 3)
            continue;
        s = s + 1;
    }
    return s;
}

int test_while_continue(void) {
    int s = 0;
    int i = 0;
    while (i < 10) {
        i++;
        if (i == 5)
            continue;
        s = s + 1;
    }
    return s;
}

int test_nested_for(int n) {
    int s = 0;
    int i;
    int j;
    for (i = 0; i < n; i++) {
        for (j = 0; j < n; j++) {
            s = s + 1;
        }
    }
    return s;
}

int test_nested_break(void) {
    int s = 0;
    int i;
    int j;
    for (i = 0; i < 5; i++) {
        for (j = 0; j < 5; j++) {
            if (j == 2)
                break;
            s = s + 1;
        }
    }
    return s;
}

int test_while_nested(void) {
    int s = 0;
    int i = 0;
    while (i < 3) {
        int j = 0;
        while (j < 4) {
            s = s + 1;
            j++;
        }
        i++;
    }
    return s;
}

int test_for_empty_init(void) {
    int s = 0;
    int i = 0;
    for (; i < 5; i++) {
        s = s + 1;
    }
    return s;
}

int main(void) {
    int r;
    r = test_while_simple(5);
    r = test_while_zero();
    r = test_do_while(5);
    r = test_for_simple(5);
    r = test_for_decl(10);
    r = test_for_compound_incr(10);
    r = test_for_break(5);
    r = test_while_break(5);
    r = test_for_continue(10);
    r = test_while_continue();
    r = test_nested_for(3);
    r = test_nested_break();
    r = test_while_nested();
    r = test_for_empty_init();
    return 0;
}
