/* Test TODO 18 : Tableaux */

int g_arr[5];

int sum_array(int *arr, int n) {
    int total = 0;
    int i = 0;
    while (i < n) {
        total += arr[i];
        i++;
    }
    return total;
}

int main() {
    int arr[5];
    int i;
    int result;

    /* Affectation aux elements du tableau */
    arr[0] = 10;
    arr[1] = 20;
    arr[2] = 30;
    arr[3] = 40;
    arr[4] = 50;

    /* Lecture d elements */
    result = arr[2];   /* result = 30 */

    /* Acces avec index variable */
    i = 3;
    result = arr[i];   /* result = 40 */

    /* Affectation composee sur element */
    arr[0] += 5;       /* arr[0] = 15 */
    arr[1] -= 10;      /* arr[1] = 10 */

    /* Tableau global */
    g_arr[0] = 100;
    g_arr[1] = 200;
    result = g_arr[0]; /* result = 100 */

    /* Passage de tableau a fonction (decay en pointeur) */
    result = sum_array(arr, 5);

    /* Boucle avec tableau */
    i = 0;
    while (i < 5) {
        arr[i] = i * 10;
        i++;
    }

    /* Boucle for avec tableau */
    for (i = 0; i < 5; i++) {
        arr[i] += 1;
    }

    result = arr[0] + arr[1] + arr[2];

    return 0;
}
