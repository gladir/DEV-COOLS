/* Test de l'opérateur ternaire ?: */

int main()
{
    int a, b, c, result;
    
    /* Tests de base */
    a = 10;
    b = 5;
    
    /* Test simple: condition vraie */
    result = (a > b) ? a : b;  /* Devrait être 10 */
    printf("max(10, 5) = %d (devrait être 10)\n", result);
    
    /* Test simple: condition fausse */
    result = (a < b) ? a : b;  /* Devrait être 5 */
    printf("condition fausse: %d (devrait être 5)\n", result);
    
    /* Test avec constantes */
    result = 1 ? 100 : 200;    /* Devrait être 100 */
    printf("1 ? 100 : 200 = %d (devrait être 100)\n", result);
    
    result = 0 ? 100 : 200;    /* Devrait être 200 */
    printf("0 ? 100 : 200 = %d (devrait être 200)\n", result);
    
    /* Test avec expressions plus complexes */
    a = 8;
    b = 3;
    c = 2;
    
    result = (a > 5) ? (b + c) : (b - c);  /* (8 > 5) = vrai, donc 3 + 2 = 5 */
    printf("(8 > 5) ? (3 + 2) : (3 - 2) = %d (devrait être 5)\n", result);
    
    result = (a < 5) ? (b + c) : (b - c);  /* (8 < 5) = faux, donc 3 - 2 = 1 */
    printf("(8 < 5) ? (3 + 2) : (3 - 2) = %d (devrait être 1)\n", result);
    
    /* Test avec opérateur ternaire imbriqué */
    a = 15;
    result = (a > 20) ? 1 : (a > 10) ? 2 : 3;  /* a = 15, donc (15 > 10) = vrai, résultat = 2 */
    printf("Ternaire imbriqué: %d (devrait être 2)\n", result);
    
    /* Test avec variables */
    a = 0;
    b = 42;
    c = 99;
    result = a ? b : c;        /* a = 0 (faux), donc résultat = c = 99 */
    printf("0 ? 42 : 99 = %d (devrait être 99)\n", result);
    
    a = 1;
    result = a ? b : c;        /* a = 1 (vrai), donc résultat = b = 42 */
    printf("1 ? 42 : 99 = %d (devrait être 42)\n", result);
    
    /* Test avec négation */
    a = 7;
    result = !a ? 0 : a;       /* !7 = 0 (faux), donc résultat = a = 7 */
    printf("!7 ? 0 : 7 = %d (devrait être 7)\n", result);
    
    return 0;
}
