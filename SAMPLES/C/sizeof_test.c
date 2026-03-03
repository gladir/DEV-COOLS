/* Test de l'opérateur sizeof */

int main()
{
    int a;
    char c;
    int arr[10];
    int *ptr;
    int result;
    
    /* Tests sizeof sur types de base */
    result = sizeof(int);        /* Devrait être 2 sur 6809 */
    printf("sizeof(int) = %d\n", result);
    
    result = sizeof(char);       /* Devrait être 1 */
    printf("sizeof(char) = %d\n", result);
    
    result = sizeof(int*);       /* Devrait être 2 (taille pointeur) */
    printf("sizeof(int*) = %d\n", result);
    
    /* Tests sizeof sur variables */
    result = sizeof(a);          /* Devrait être 2 */
    printf("sizeof(a) = %d\n", result);
    
    result = sizeof(c);          /* Devrait être 1 */
    printf("sizeof(c) = %d\n", result);
    
    result = sizeof(arr);        /* Devrait être 10 * 2 = 20 */
    printf("sizeof(arr) = %d\n", result);
    
    result = sizeof(ptr);        /* Devrait être 2 (taille pointeur) */
    printf("sizeof(ptr) = %d\n", result);
    
    /* Tests sizeof sur expressions */
    result = sizeof(a + c);      /* Type résultat int, devrait être 2 */
    printf("sizeof(a + c) = %d\n", result);
    
    result = sizeof(*ptr);       /* Type pointé int, devrait être 2 */
    printf("sizeof(*ptr) = %d\n", result);
    
    return 0;
}
