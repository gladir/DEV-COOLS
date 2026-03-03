/* Test simple de l'opérateur ternaire */

int main()
{
    int a, b, result;
    
    a = 10;
    b = 5;
    
    /* Test basique */
    result = (a > b) ? a : b;
    
    /* Test avec zéro */
    result = 0 ? 1 : 2;
    
    /* Test avec un */
    result = 1 ? 3 : 4;
    
    return 0;
}
