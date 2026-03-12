/* Test des fonctions stdlib.h built-in pour CCW32 */
#include <stdio.h>
#include <stdlib.h>

int main() {
    printf("=== Test stdlib.h ===\n");

    /* abs */
    int a = abs(-42);
    printf("abs(-42)=%d\n", a);

    int b = abs(42);
    printf("abs(42)=%d\n", b);

    /* atoi */
    int c = atoi("123");
    printf("atoi(123)=%d\n", c);

    /* malloc et free */
    int *p = (int *)malloc(4);
    if (p) {
        *p = 999;
        printf("malloc+store=%d\n", *p);
        free(p);
        printf("free: OK\n");
    }

    /* calloc */
    int *q = (int *)calloc(4, 4);
    if (q) {
        printf("calloc[0]=%d\n", q[0]);
        free(q);
    }

    /* exit test - ne pas executer pour ne pas arreter */
    printf("stdlib.h: OK\n");
    return 0;
}
