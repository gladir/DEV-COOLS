/* Test simple de l'opérateur ! */

int main()
{
    int a, result;
    
    /* Test basique */
    a = 0;
    result = !a;
    
    a = 5;
    result = !a;
    
    /* Test avec expression */
    result = !(a > 0);
    
    return 0;
}
