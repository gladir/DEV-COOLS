/* Test des operations sur la memoire pour CCW32 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    printf("=== Test memory ops ===\n");

    /* malloc/free */
    int *p1 = (int *)malloc(16);
    if (p1) {
        p1[0] = 10;
        p1[1] = 20;
        p1[2] = 30;
        p1[3] = 40;
        printf("p1[0]=%d p1[3]=%d\n", p1[0], p1[3]);
        free(p1);
        printf("malloc/free: OK\n");
    }

    /* calloc */
    int *p2 = (int *)calloc(8, 4);
    if (p2) {
        printf("calloc[0]=%d\n", p2[0]);
        p2[0] = 100;
        printf("calloc[0]=%d\n", p2[0]);
        free(p2);
        printf("calloc: OK\n");
    }

    /* realloc */
    int *p3 = (int *)malloc(4);
    if (p3) {
        *p3 = 42;
        int *p4 = (int *)realloc(p3, 16);
        if (p4) {
            printf("realloc[0]=%d\n", p4[0]);
            free(p4);
        }
        printf("realloc: OK\n");
    }

    printf("memory: OK\n");
    return 0;
}
