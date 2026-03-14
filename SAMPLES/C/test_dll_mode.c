/* Test du mode DLL pour CCW32 */
/* Ce fichier est compile avec: CCW32 test_dll_mode.c -dll */

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}

int subtract(int a, int b) {
    return a - b;
}
