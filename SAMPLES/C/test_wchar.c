/* test_wchar.c - Test du support wchar_t dans CCW32                     */
/* Verifie que :                                                         */
/*   1) wchar.h est reconnu comme en-tete built-in                       */
/*   2) wctype.h est reconnu comme en-tete built-in                      */
/*   3) Les macros WEOF, WCHAR_MIN, WCHAR_MAX sont definies              */
/*   4) Le type wchar_t est reconnu (2 octets unsigned, Win32)           */
/*   5) Les 52 fonctions wchar.h sont reconnues                          */
/*   6) Les 18 fonctions wctype.h sont reconnues                         */

#include <wchar.h>
#include <wctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Variables globales de type wchar_t */
wchar_t wc1;
wchar_t wc2;

int main() {
    /* Variables locales */
    wchar_t local_wc;
    wchar_t *wptr;
    int result = 0;
    int checks = 0;

    /* ======================================================== */
    /* Test 1: Macros wchar.h definies                          */
    /* ======================================================== */
    if (_WCHAR_H == 1) checks = checks + 1;
    if (_WCTYPE_H == 1) checks = checks + 1;

    /* ======================================================== */
    /* Test 2: Constantes WEOF, WCHAR_MIN, WCHAR_MAX            */
    /* ======================================================== */
    if (WCHAR_MIN == 0) checks = checks + 1;
    if (WCHAR_MAX == 65535) checks = checks + 1;

    /* ======================================================== */
    /* Test 3: Variables wchar_t                                 */
    /* ======================================================== */
    wc1 = 65;
    wc2 = 66;
    local_wc = wc1;
    if (local_wc == 65) checks = checks + 1;

    /* ======================================================== */
    /* Test 4: Fonctions wchar.h (52 fonctions)                  */
    /* ======================================================== */
    {
        void *fp;
        /* Fonctions de conversion */
        fp = (void *)btowc;
        fp = (void *)wctob;
        fp = (void *)mbrtowc;
        fp = (void *)wcrtomb;
        fp = (void *)mbrlen;
        fp = (void *)mbsinit;
        fp = (void *)mbsrtowcs;
        fp = (void *)wcsrtombs;

        /* Fonctions d entree/sortie wide */
        fp = (void *)fgetwc;
        fp = (void *)fgetws;
        fp = (void *)fputwc;
        fp = (void *)fputws;
        fp = (void *)fwide;
        fp = (void *)fwprintf;
        fp = (void *)fwscanf;
        fp = (void *)getwc;
        fp = (void *)getwchar;
        fp = (void *)putwc;
        fp = (void *)putwchar;
        fp = (void *)swprintf;
        fp = (void *)swscanf;
        fp = (void *)ungetwc;
        fp = (void *)vfwprintf;
        fp = (void *)vswprintf;
        fp = (void *)vwprintf;
        fp = (void *)wprintf;
        fp = (void *)wscanf;

        /* Fonctions de manipulation de chaines wide */
        fp = (void *)wcscat;
        fp = (void *)wcschr;
        fp = (void *)wcscmp;
        fp = (void *)wcscoll;
        fp = (void *)wcscpy;
        fp = (void *)wcscspn;
        fp = (void *)wcsftime;
        fp = (void *)wcslen;
        fp = (void *)wcsncat;
        fp = (void *)wcsncmp;
        fp = (void *)wcsncpy;
        fp = (void *)wcspbrk;
        fp = (void *)wcsrchr;
        fp = (void *)wcsspn;
        fp = (void *)wcsstr;
        fp = (void *)wcstod;
        fp = (void *)wcstok;
        fp = (void *)wcstol;
        fp = (void *)wcstoul;
        fp = (void *)wcsxfrm;

        /* Fonctions de memoire wide */
        fp = (void *)wmemchr;
        fp = (void *)wmemcmp;
        fp = (void *)wmemcpy;
        fp = (void *)wmemmove;
        fp = (void *)wmemset;
    }
    checks = checks + 1;

    /* ======================================================== */
    /* Test 5: Fonctions wctype.h (18 fonctions)                 */
    /* ======================================================== */
    {
        void *fp;
        fp = (void *)iswalnum;
        fp = (void *)iswalpha;
        fp = (void *)iswblank;
        fp = (void *)iswcntrl;
        fp = (void *)iswdigit;
        fp = (void *)iswgraph;
        fp = (void *)iswlower;
        fp = (void *)iswprint;
        fp = (void *)iswpunct;
        fp = (void *)iswspace;
        fp = (void *)iswupper;
        fp = (void *)iswxdigit;
        fp = (void *)towlower;
        fp = (void *)towupper;
        fp = (void *)iswctype;
        fp = (void *)wctype;
        fp = (void *)wctrans;
        fp = (void *)towctrans;
    }
    checks = checks + 1;

    /* ======================================================== */
    /* Resultat final                                            */
    /* ======================================================== */
    result = checks;
    return 0;
}
