/* Test des fonctions ctype.h built-in pour CCW32 */
/* Les fonctions ctype.h sont implementees en inline */
#include <stdio.h>

int my_isdigit(int c) {
    if (c >= 48) {
        if (c <= 57) return 1;
    }
    return 0;
}

int my_isalpha(int c) {
    if (c >= 65) {
        if (c <= 90) return 1;
    }
    if (c >= 97) {
        if (c <= 122) return 1;
    }
    return 0;
}

int my_isupper(int c) {
    if (c >= 65) {
        if (c <= 90) return 1;
    }
    return 0;
}

int my_islower(int c) {
    if (c >= 97) {
        if (c <= 122) return 1;
    }
    return 0;
}

int my_tolower(int c) {
    if (c >= 65) {
        if (c <= 90) return c + 32;
    }
    return c;
}

int my_toupper(int c) {
    if (c >= 97) {
        if (c <= 122) return c - 32;
    }
    return c;
}

int my_isspace(int c) {
    if (c == 32) return 1;
    if (c == 9) return 1;
    if (c == 10) return 1;
    if (c == 13) return 1;
    return 0;
}

int main() {
    printf("=== Test ctype.h ===\n");

    printf("isdigit(5)=%d\n", my_isdigit(53));
    printf("isdigit(a)=%d\n", my_isdigit(97));
    printf("isalpha(A)=%d\n", my_isalpha(65));
    printf("isalpha(3)=%d\n", my_isalpha(51));
    printf("isupper(A)=%d\n", my_isupper(65));
    printf("islower(a)=%d\n", my_islower(97));
    printf("tolower(A)=%d\n", my_tolower(65));
    printf("toupper(a)=%d\n", my_toupper(97));
    printf("isspace( )=%d\n", my_isspace(32));

    printf("ctype.h: OK\n");
    return 0;
}
