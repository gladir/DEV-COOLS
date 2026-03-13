/* Test des fonctions stdio.h built-in pour CCW32 */
#include <stdio.h>

int main() {
    /* printf - formats de base */
    printf("=== Test stdio.h ===\n");
    printf("Integer: %d\n", 42);
    printf("Unsigned: %u\n", 255);
    printf("Hex: %x\n", 255);
    printf("Char: %c\n", 65);
    printf("String: %s\n", "hello");
    printf("Percent: %%\n");
    printf("Multiple: %d %d %d\n", 1, 2, 3);

    /* puts */
    puts("puts test OK");

    /* putchar */
    putchar('Z');
    putchar('\n');

    /* printf avec variables */
    int x = 100;
    int y = 200;
    printf("x=%d y=%d sum=%d\n", x, y, x + y);

    /* printf negatif */
    int neg = -42;
    printf("neg=%d\n", neg);

    /* printf zero */
    printf("zero=%d\n", 0);

    printf("stdio.h: OK\n");
    return 0;
}
