/* Test du mode ASM pour CCW32 */
/* Ce fichier est compile avec: CCW32 test_asm_mode.c -asm */
/* Verifie que le fichier .asm est cree en plus du .exe */
#include <stdio.h>

int square(int x) {
    return x * x;
}

int main() {
    printf("square(7)=%d\n", square(7));
    printf("asm_mode: OK\n");
    return 0;
}
