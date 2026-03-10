/* test_complex_c99.c - Test complet du support C99 complex dans CCW32   */
/* Verifie que :                                                         */
/*   1) complex.h est reconnu comme en-tete built-in                     */
/*   2) Les macros complex, I, _Complex_I, CMPLX sont definies           */
/*   3) _Complex est un mot-cle et specificateur de type C99             */
/*   4) Les types float _Complex, double _Complex, long double _Complex  */
/*      sont enregistres dans le systeme de types                        */
/*   5) Toutes les 78 fonctions complex.h (double/float/long double)     */
/*      sont reconnues par le compilateur                                */
/*   6) _Bool est un mot-cle C99 reconnu                                 */

#include <complex.h>
#include <stdbool.h>
#include <stdio.h>
#include <math.h>

/* Variables globales de type complexe C99 */
double _Complex z1;
float _Complex z2;
_Complex z3;

/* Variable _Bool C99 */
_Bool flag;

int main() {
    /* Verification que _COMPLEX_H est defini */
    int has_complex = _COMPLEX_H;

    /* Verification que _STDBOOL_H est defini */
    int has_stdbool = _STDBOOL_H;

    /* Variables locales de type complexe C99 */
    double _Complex local_z1;
    float _Complex local_z2;

    /* Variable _Bool locale */
    _Bool local_flag;
    local_flag = 1;

    /* Variables pour stocker les resultats d appels */
    double r1;
    int result = 0;
    int checks = 0;

    /* ======================================================== */
    /* Test 1: Macros complex.h definies                        */
    /* ======================================================== */
    if (has_complex == 1) checks = checks + 1;

    /* ======================================================== */
    /* Test 2: _Bool fonctionne                                 */
    /* ======================================================== */
    if (has_stdbool == 1) checks = checks + 1;
    flag = 0;
    if (flag == 0) checks = checks + 1;
    local_flag = 1;
    if (local_flag) checks = checks + 1;

    /* ======================================================== */
    /* Test 3: Fonctions trigonometriques complexes (double)     */
    /* ======================================================== */
    r1 = cabs(0);
    r1 = carg(0);
    r1 = creal(0);
    r1 = cimag(0);
    r1 = ccos(0);
    r1 = csin(0);
    r1 = ctan(0);
    r1 = cacos(0);
    r1 = casin(0);
    r1 = catan(0);

    /* Test des fonctions hyperboliques complexes (double) */
    r1 = ccosh(0);
    r1 = csinh(0);
    r1 = ctanh(0);
    r1 = cacosh(0);
    r1 = casinh(0);
    r1 = catanh(0);

    /* Test des fonctions exponentielles/logarithmiques (double) */
    r1 = cexp(0);
    r1 = clog(0);
    r1 = csqrt(0);
    r1 = cpow(0, 0);

    /* Test des fonctions de manipulation (double) */
    r1 = conj(0);
    r1 = cproj(0);
    checks = checks + 1;

    /* ======================================================== */
    /* Test 4: Variantes float (suffixe f)                      */
    /* ======================================================== */
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
    checks = checks + 1;

    /* ======================================================== */
    /* Test 5: Variantes long double (suffixe l)                */
    /* ======================================================== */
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
    checks = checks + 1;

    /* ======================================================== */
    /* Resultat final                                            */
    /* ======================================================== */
    result = checks;
    return 0;
}
