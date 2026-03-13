/* test_func_proto.c : test des fonctions et prototypes (TODO 16) */
#include <stdio.h>

/* --- Prototypes (declarations avancees) --- */
int add(int a, int b);
int sub(int a, int b);
int factorial(int n);
void do_nothing(void);
int max_of(int a, int b);

/* --- Fonctions extern (declarations sans corps) --- */
extern int ext_func(int x);

/* --- Fonction static (visibilite fichier) --- */
static int helper(int x) {
    return x * 2;
}

/* --- Definitions des fonctions declarees --- */

int add(int a, int b) {
    return a + b;
}

int sub(int a, int b) {
    return a - b;
}

/* Fonction recursive */
int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

/* Fonction void */
void do_nothing(void) {
    int x = 0;
}

/* Fonction avec if */
int max_of(int a, int b) {
    if (a > b) return a;
    return b;
}

/* Fonction avec plusieurs variables locales */
int compute(int a, int b, int c) {
    int sum = a + b + c;
    int avg = sum / 3;
    return avg;
}

/* Fonction appelant d autres fonctions */
int chain_call(int x) {
    int a = add(x, 1);
    int b = sub(a, 2);
    int c = helper(b);
    return c;
}

/* Fonction avec beaucoup de parametres */
int sum5(int a, int b, int c, int d, int e) {
    return a + b + c + d + e;
}

int main(void) {
    int r;

    /* Test appel simple */
    r = add(3, 4);

    /* Test soustraction */
    r = sub(10, 3);

    /* Test recursion (factorielle) */
    r = factorial(5);

    /* Test void */
    do_nothing();

    /* Test max */
    r = max_of(10, 20);
    r = max_of(30, 15);

    /* Test compute */
    r = compute(6, 9, 12);

    /* Test chaine d appels */
    r = chain_call(5);

    /* Test 5 parametres */
    r = sum5(1, 2, 3, 4, 5);

    /* Test static helper */
    r = helper(7);

    return 0;
}
