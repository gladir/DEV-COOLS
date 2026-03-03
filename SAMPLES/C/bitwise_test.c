/* Test des opérateurs binaires */

int main()
{
    int a, b, result;
    
    a = 5;   /* 101 en binaire */
    b = 3;   /* 011 en binaire */
    
    /* Test AND binaire */
    result = a & b;  /* Devrait donner 001 = 1 */
    printf("a & b = %d\n", result);
    
    /* Test OR binaire */
    result = a | b;  /* Devrait donner 111 = 7 */
    printf("a | b = %d\n", result);
    
    /* Test XOR binaire */
    result = a ^ b;  /* Devrait donner 110 = 6 */
    printf("a ^ b = %d\n", result);
    
    return 0;
}
