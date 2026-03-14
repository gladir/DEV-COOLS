/* Test des casts explicites, ternaire et sizeof (TODO 23) */

int main()
{
    int i;
    char c;
    int result;
    int *ptr;

    /* --- Cast explicite (char)int : troncature --- */
    i = 321;
    c = (char)i;

    /* --- Cast explicite (int)char : extension signe --- */
    c = 65;
    i = (int)c;

    /* --- Cast (unsigned char) : troncature 8 bits --- */
    i = 256 + 42;
    result = (unsigned char)i;

    /* --- Cast (short) : extension signe 16 bits --- */
    i = 1000;
    result = (short)i;

    /* --- Cast (unsigned short) : troncature 16 bits --- */
    i = 65536 + 100;
    result = (unsigned short)i;

    /* --- Cast pointeur : no-op en 32 bits --- */
    i = 42;
    ptr = (int *)0;

    /* --- Operateur ternaire simple --- */
    i = 10;
    result = (i > 5) ? 1 : 0;

    /* --- Ternaire avec zero --- */
    result = 0 ? 100 : 200;

    /* --- Ternaire avec un --- */
    result = 1 ? 300 : 400;

    /* --- Ternaire imbrique --- */
    i = 3;
    result = (i > 5) ? 10 : (i > 2) ? 20 : 30;

    /* --- sizeof sur types de base --- */
    result = sizeof(int);
    result = sizeof(char);

    /* --- sizeof sur expression --- */
    result = sizeof(i);

    return 0;
}
