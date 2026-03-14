/* test_complex.c - Test du support complex.h (C99) dans CCW32 */
/* Verifie que l en-tete complex.h est reconnu comme built-in  */
/* et que les fonctions complexes C99 sont toutes enregistrees  */

#include <complex.h>
#include <math.h>
#include <stdio.h>

int main() {
    /* Verification que _COMPLEX_H est defini */
    int has_complex = _COMPLEX_H;

    /* Variables pour stocker les resultats d appels */
    double r1, r2, r3, r4;
    int result = 0;

    /* Test des fonctions trigonometriques complexes (double) */
    r1 = cabs(0);
    r1 = carg(0);
    r1 = creal(0);
    r1 = cimag(0);

    /* Test des fonctions trigonometriques */
    r1 = ccos(0);
    r1 = csin(0);
    r1 = ctan(0);
    r1 = cacos(0);
    r1 = casin(0);
    r1 = catan(0);

    /* Test des fonctions hyperboliques */
    r1 = ccosh(0);
    r1 = csinh(0);
    r1 = ctanh(0);
    r1 = cacosh(0);
    r1 = casinh(0);
    r1 = catanh(0);

    /* Test des fonctions exponentielles et logarithmiques */
    r1 = cexp(0);
    r1 = clog(0);
    r1 = csqrt(0);
    r1 = cpow(0, 0);

    /* Test des fonctions de manipulation */
    r1 = conj(0);
    r1 = cproj(0);

    /* Test des variantes float (suffixe f) */
    r1 = cabsf(0);
    r1 = cargf(0);
    r1 = crealf(0);
    r1 = cimagf(0);
    r1 = ccosf(0);
    r1 = csinf(0);
    r1 = ctanf(0);
    r1 = cacosf(0);
    r1 = casinf(0);
    r1 = catanf(0);
    r1 = ccoshf(0);
    r1 = csinhf(0);
    r1 = ctanhf(0);
    r1 = cacoshf(0);
    r1 = casinhf(0);
    r1 = catanhf(0);
    r1 = cexpf(0);
    r1 = clogf(0);
    r1 = csqrtf(0);
    r1 = cpowf(0, 0);
    r1 = conjf(0);
    r1 = cprojf(0);

    /* Test des variantes long double (suffixe l) */
    r1 = cabsl(0);
    r1 = cargl(0);
    r1 = creall(0);
    r1 = cimagl(0);
    r1 = ccosl(0);
    r1 = csinl(0);
    r1 = ctanl(0);
    r1 = cacosl(0);
    r1 = casinl(0);
    r1 = catanl(0);
    r1 = ccoshl(0);
    r1 = csinhl(0);
    r1 = ctanhl(0);
    r1 = cacoshl(0);
    r1 = casinhl(0);
    r1 = catanhl(0);
    r1 = cexpl(0);
    r1 = clogl(0);
    r1 = csqrtl(0);
    r1 = cpowl(0, 0);
    r1 = conjl(0);
    r1 = cprojl(0);

    /* Si on arrive ici, toutes les fonctions complex.h sont reconnues */
    result = has_complex;
    return result;
}
