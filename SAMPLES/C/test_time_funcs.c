/* Test des fonctions time.h built-in pour CCW32 */
#include <stdio.h>
#include <time.h>

int main() {
    printf("=== Test time.h ===\n");

    /* time - appel de base */
    time_t t = time(0);
    printf("time()=%d\n", t);

    /* clock */
    clock_t c = clock();
    printf("clock()=%d\n", c);

    printf("time.h: OK\n");
    return 0;
}
