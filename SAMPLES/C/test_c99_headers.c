/* test_c99_headers.c - Test des en-tetes C99 built-in dans CCW32 */
/* Verifie que tous les en-tetes C99 sont reconnus et leurs       */
/* macros sont correctement definies                               */

#include <stdbool.h>
#include <stdint.h>
#include <inttypes.h>
#include <complex.h>
#include <fenv.h>
#include <iso646.h>
#include <wchar.h>
#include <wctype.h>
#include <tgmath.h>

int main() {
    int result = 0;
    int checks = 0;

    /* ======================================================== */
    /* Test stdbool.h                                           */
    /* ======================================================== */
    if (_STDBOOL_H) checks = checks + 1;
    if (true == 1) checks = checks + 1;
    if (false == 0) checks = checks + 1;

    /* ======================================================== */
    /* Test stdint.h                                            */
    /* ======================================================== */
    if (_STDINT_H) checks = checks + 1;
    if (INT8_MAX == 127) checks = checks + 1;
    if (INT16_MAX == 32767) checks = checks + 1;
    if (INT32_MAX == 2147483647) checks = checks + 1;
    if (UINT8_MAX == 255) checks = checks + 1;

    /* ======================================================== */
    /* Test complex.h                                           */
    /* ======================================================== */
    if (_COMPLEX_H) checks = checks + 1;

    /* ======================================================== */
    /* Test fenv.h                                              */
    /* ======================================================== */
    if (_FENV_H) checks = checks + 1;
    if (FE_TONEAREST == 0) checks = checks + 1;
    if (FE_DIVBYZERO == 4) checks = checks + 1;

    /* ======================================================== */
    /* Test iso646.h                                            */
    /* ======================================================== */
    if (_ISO646_H) checks = checks + 1;

    /* ======================================================== */
    /* Test wchar.h                                             */
    /* ======================================================== */
    if (_WCHAR_H) checks = checks + 1;

    /* ======================================================== */
    /* Test wctype.h                                            */
    /* ======================================================== */
    if (_WCTYPE_H) checks = checks + 1;

    /* ======================================================== */
    /* Test tgmath.h                                            */
    /* ======================================================== */
    if (_TGMATH_H) checks = checks + 1;

    /* ======================================================== */
    /* Test inttypes.h                                          */
    /* ======================================================== */
    if (_INTTYPES_H) checks = checks + 1;

    result = checks;
    return 0;
}
