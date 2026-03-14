/* Test printf avec tous les formats supportes par CCW32 */
#include <stdio.h>

int main() {
    printf("=== Test printf formats ===\n");

    /* %d - entier signe */
    printf("%d\n", 0);
    printf("%d\n", 1);
    printf("%d\n", -1);
    printf("%d\n", 2147483647);
    printf("%d\n", -2147483647);
    printf("%d\n", 42);
    printf("%d\n", -42);

    /* %u - entier non signe */
    printf("%u\n", 0);
    printf("%u\n", 42);
    printf("%u\n", 4294967295);

    /* %x - hexadecimal */
    printf("%x\n", 0);
    printf("%x\n", 255);
    printf("%x\n", 4096);
    printf("%x\n", 65535);

    /* %c - caractere */
    printf("%c\n", 65);
    printf("%c\n", 90);
    printf("%c\n", 48);
    printf("%c\n", 57);

    /* %s - chaine */
    printf("%s\n", "hello");
    printf("%s\n", "world");
    printf("%s\n", "");

    /* %% - pourcent literal */
    printf("100%%\n");

    /* Combinaisons multiples */
    printf("%d+%d=%d\n", 3, 4, 7);
    printf("%s=%d\n", "answer", 42);
    printf("%c%c%c\n", 65, 66, 67);

    printf("printf_formats: OK\n");
    return 0;
}
