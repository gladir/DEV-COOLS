/* Test TODO 17 : Pointeurs et adresses */

int g_val;
int *g_ptr;

/* Fonction callback pour test de pointeur de fonction */
int add_one(int x) {
    return x + 1;
}

int double_val(int x) {
    return x * 2;
}

int main() {
    int a = 42;
    int b = 0;
    int *p;
    int *q;
    int **pp;
    void *vp;
    int *fp;

    /* Adresse de et dereferencement */
    p = &a;
    b = *p;         /* b = 42 */

    /* Affectation via dereferencement */
    *p = 100;       /* a = 100 */

    /* Pointeur NULL */
    q = 0;

    /* Pointeur global */
    g_val = 55;
    g_ptr = &g_val;
    b = *g_ptr;     /* b = 55 */

    /* Pointeur void */
    vp = &a;

    /* Pointeur de pointeur */
    pp = &p;

    /* Comparaison de pointeurs */
    if (p == &a) {
        b = 1;
    }
    if (q == 0) {
        b = 2;
    }
    if (p != q) {
        b = 3;
    }

    /* Arithmetique de pointeurs : p++ et p-- (mise a l echelle) */
    p = &a;
    p++;            /* avance de sizeof(int) = 4 octets */
    p--;            /* recule de sizeof(int) = 4 octets */

    /* Pre-increment et pre-decrement sur pointeur */
    ++p;
    --p;

    /* Affectation composee sur dereferencement */
    p = &a;
    *p = 50;
    *p += 10;       /* a = 60 */

    /* Pointeur de fonction (utilise int* comme type) */
    fp = (int *)&add_one;
    b = fp(10);     /* b = 11 (appel indirect) */

    fp = (int *)&double_val;
    b = fp(5);      /* b = 10 (appel indirect) */

    return 0;
}
