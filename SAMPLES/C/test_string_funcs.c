/* Test des fonctions string.h built-in pour CCW32 */
#include <stdio.h>
#include <string.h>

int main() {
    printf("=== Test string.h ===\n");

    /* strlen */
    int len = strlen("hello");
    printf("strlen(hello)=%d\n", len);

    /* strcmp */
    int cmp1 = strcmp("abc", "abc");
    printf("strcmp(abc,abc)=%d\n", cmp1);

    int cmp2 = strcmp("abc", "def");
    printf("strcmp(abc,def)=%d\n", cmp2);

    /* memset - via buffer local */
    char buf[32];
    memset(buf, 0, 32);
    printf("memset: OK\n");

    /* memcpy */
    char src[8];
    char dst[8];
    src[0] = 'A';
    src[1] = 'B';
    src[2] = 0;
    memcpy(dst, src, 3);
    printf("memcpy: %c%c\n", dst[0], dst[1]);

    /* strcpy */
    char s1[16];
    strcpy(s1, "test");
    printf("strcpy: OK\n");

    /* strcat */
    char s2[32];
    strcpy(s2, "hel");
    strcat(s2, "lo");
    printf("strcat: OK\n");

    printf("string.h: OK\n");
    return 0;
}
