/* test_pe.c : test de la generation PE/COFF (TODO 25) */
/* Teste : printf, scanf, variables locales, pointeurs, boucle, conditions */

int main()
{
    int i;
    int sum;
    int n;
    char buf[32];

    printf("PE test: Hello from CCW32!\n");
    printf("Sum of 1..10 = ");
    sum = 0;
    for (i = 1; i <= 10; i++) {
        sum = sum + i;
    }
    printf("%d\n", sum);

    n = 42;
    if (n > 0) {
        printf("n is positive: %d\n", n);
    } else {
        printf("n is not positive\n");
    }

    return 0;
}
