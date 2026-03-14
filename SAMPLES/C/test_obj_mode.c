/* Test du mode OBJ pour CCW32 */
/* Ce fichier est compile avec: CCW32 test_obj_mode.c -obj */
/* Verifie que le fichier .obj (COFF) est cree */

int helper(int x) {
    return x + 1;
}

int compute(int a, int b) {
    return helper(a) + helper(b);
}
