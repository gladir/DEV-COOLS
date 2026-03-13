/* test_goto.c - Test goto, labels, break, continue, return (TODO 22) */
#include <stdio.h>

int test_simple_goto() {
    int x = 1;
    goto skip;
    x = 99;
skip:
    return x;
}

int test_goto_forward() {
    int r = 0;
    goto label2;
label1:
    r = r + 1;
    goto label3;
label2:
    r = r + 10;
    goto label1;
label3:
    return r;
}

int test_goto_in_if() {
    int v = 5;
    if (v > 3) {
        goto done;
    }
    v = 0;
done:
    return v;
}

int test_break_in_loop() {
    int i = 0;
    int s = 0;
    for (i = 0; i < 10; i++) {
        if (i == 5) break;
        s = s + i;
    }
    return s;
}

int test_continue_in_loop() {
    int i = 0;
    int s = 0;
    for (i = 0; i < 5; i++) {
        if (i == 2) continue;
        s = s + i;
    }
    return s;
}

int test_return_void() {
    return;
}

int test_return_expr() {
    return 42;
}

int main() {
    printf("test_simple_goto = %d\n", test_simple_goto());
    printf("test_goto_forward = %d\n", test_goto_forward());
    printf("test_goto_in_if = %d\n", test_goto_in_if());
    printf("test_break_in_loop = %d\n", test_break_in_loop());
    printf("test_continue_in_loop = %d\n", test_continue_in_loop());
    printf("test_return_expr = %d\n", test_return_expr());
    return 0;
}
