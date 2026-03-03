/* Test avancé de l'opérateur ! avec des expressions complexes */

int main()
{
    int a, b, c, result;
    
    a = 10;
    b = 5;
    c = 0;
    
    /* Tests de base */
    result = !0;      /* Devrait être 1 */
    result = !1;      /* Devrait être 0 */
    result = !42;     /* Devrait être 0 */
    result = !(-5);   /* Devrait être 0 */
    
    /* Tests avec variables */
    result = !a;      /* !10 = 0 */
    result = !c;      /* !0 = 1 */
    
    /* Tests avec expressions relationnelles */
    result = !(a > b);     /* !(10 > 5) = !1 = 0 */
    result = !(a < b);     /* !(10 < 5) = !0 = 1 */
    result = !(a == b);    /* !(10 == 5) = !0 = 1 */
    result = !(c == 0);    /* !(0 == 0) = !1 = 0 */
    
    /* Tests avec expressions arithmétiques */
    result = !(a + b);     /* !(10 + 5) = !15 = 0 */
    result = !(c * a);     /* !(0 * 10) = !0 = 1 */
    result = !(b - a);     /* !(5 - 10) = !(-5) = 0 */
    
    /* Tests avec double négation */
    result = !!a;          /* !!10 = !0 = 1 */
    result = !!c;          /* !!0 = !1 = 0 */
    result = !!(a > b);    /* !!(10 > 5) = !!1 = !0 = 1 */
    
    /* Tests avec expressions complexes */
    result = !(a && b);    /* !(10 && 5) = !1 = 0 */
    result = !(c || a);    /* !(0 || 10) = !1 = 0 */
    result = !(a & b);     /* !(10 & 5) = !(10 & 5) */
    
    /* Tests dans des conditions if */
    if (!c) {
        /* Cette branche devrait être exécutée car !0 = 1 */
        a = 99;
    }
    
    if (!(a > 100)) {
        /* Cette branche devrait être exécutée car !(99 > 100) = !0 = 1 */
        b = 88;
    }
    
    return 0;
}
