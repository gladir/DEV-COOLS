/* Test simple de sizeof */

int main()
{
    int result;
    
    /* Tests de base */
    result = sizeof(int);
    result = sizeof(char);
    
    /* Test sur variable */
    int a;
    result = sizeof(a);
    
    return 0;
}
