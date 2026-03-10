/* test_runtime.c - Test du runtime minimal Win32 (TODO 24) */
/* Teste les fonctions _CCRT_* generees par EmitRuntime       */
#include <stdio.h>

int main() {
    int x = 42;
    int y = -7;
    char msg[] = "Runtime OK";

    /* printf utilise _CCRT_PRINTSTR, _CCRT_PRINTINT, _CCRT_PRINTCRLF */
    printf("x = %d\n", x);
    printf("y = %d\n", y);
    printf("%s\n", msg);

    /* putchar utilise _CCRT_PRINTCHAR */
    putchar('R');
    putchar('\n');

    /* printf %u utilise _CCRT_PRINTUINT */
    printf("%u\n", 100);

    /* printf %x utilise _CCRT_PRINTHEX */
    printf("%x\n", 255);

    return 0;
}
