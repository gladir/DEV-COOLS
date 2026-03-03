/* Test de l'opérateur ! (NOT logique) */

int main()
{
    int a, b, result;
    
    /* Test du NOT logique avec différentes valeurs */
    a = 0;
    result = !a;    /* !0 devrait donner 1 (vrai) */
    printf("!0 = %d (devrait être 1)\n", result);
    
    a = 1;
    result = !a;    /* !1 devrait donner 0 (faux) */
    printf("!1 = %d (devrait être 0)\n", result);
    
    a = 5;
    result = !a;    /* !5 devrait donner 0 (faux) */
    printf("!5 = %d (devrait être 0)\n", result);
    
    a = -3;
    result = !a;    /* !-3 devrait donner 0 (faux) */
    printf("!(-3) = %d (devrait être 0)\n", result);
    
    /* Test avec expressions */
    a = 10;
    b = 5;
    result = !(a > b);   /* !(10 > 5) = !1 = 0 */
    printf("!(10 > 5) = %d (devrait être 0)\n", result);
    
    result = !(a < b);   /* !(10 < 5) = !0 = 1 */
    printf("!(10 < 5) = %d (devrait être 1)\n", result);
    
    /* Test avec double négation */
    a = 0;
    result = !!a;    /* !!0 = !1 = 0 */
    printf("!!0 = %d (devrait être 0)\n", result);
    
    a = 7;
    result = !!a;    /* !!7 = !0 = 1 */
    printf("!!7 = %d (devrait être 1)\n", result);
    
    return 0;
}
