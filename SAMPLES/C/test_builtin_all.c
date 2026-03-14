/* Test complet de toutes les fonctions C standard built-in de CCW32 */
/* Verifie que le compilateur accepte toutes les fonctions enregistrees */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <ctype.h>
#include <signal.h>
#include <setjmp.h>
#include <assert.h>
#include <stdarg.h>

/* Declarations de pointeurs de fonctions pour tester la compilation */

/* stdio.h - 41 fonctions */
void test_stdio_decl() {
    void *fp;
    /* Pointeurs : verification que les noms sont acceptes */
    fp = (void *)clearerr;
    fp = (void *)fclose;
    fp = (void *)feof;
    fp = (void *)ferror;
    fp = (void *)fflush;
    fp = (void *)fgetc;
    fp = (void *)fgetpos;
    fp = (void *)fgets;
    fp = (void *)fopen;
    fp = (void *)fprintf;
    fp = (void *)fputc;
    fp = (void *)fputs;
    fp = (void *)fread;
    fp = (void *)freopen;
    fp = (void *)fscanf;
    fp = (void *)fseek;
    fp = (void *)fsetpos;
    fp = (void *)ftell;
    fp = (void *)fwrite;
    fp = (void *)getc;
    fp = (void *)getchar;
    fp = (void *)gets;
    fp = (void *)perror;
    fp = (void *)printf;
    fp = (void *)putc;
    fp = (void *)putchar;
    fp = (void *)puts;
    fp = (void *)remove;
    fp = (void *)rename;
    fp = (void *)rewind;
    fp = (void *)scanf;
    fp = (void *)setbuf;
    fp = (void *)setvbuf;
    fp = (void *)sprintf;
    fp = (void *)sscanf;
    fp = (void *)tmpfile;
    fp = (void *)tmpnam;
    fp = (void *)ungetc;
    fp = (void *)vfprintf;
    fp = (void *)vprintf;
    fp = (void *)vsprintf;
}

/* stdlib.h - 23 fonctions */
void test_stdlib_decl() {
    void *fp;
    fp = (void *)abort;
    fp = (void *)abs;
    fp = (void *)atexit;
    fp = (void *)atof;
    fp = (void *)atoi;
    fp = (void *)atol;
    fp = (void *)bsearch;
    fp = (void *)calloc;
    fp = (void *)div;
    fp = (void *)exit;
    fp = (void *)free;
    fp = (void *)getenv;
    fp = (void *)labs;
    fp = (void *)ldiv;
    fp = (void *)malloc;
    fp = (void *)qsort;
    fp = (void *)rand;
    fp = (void *)realloc;
    fp = (void *)srand;
    fp = (void *)strtod;
    fp = (void *)strtol;
    fp = (void *)strtoul;
    fp = (void *)system;
}

/* string.h - 20 fonctions */
void test_string_decl() {
    void *fp;
    fp = (void *)memchr;
    fp = (void *)memcmp;
    fp = (void *)memcpy;
    fp = (void *)memmove;
    fp = (void *)memset;
    fp = (void *)strcat;
    fp = (void *)strchr;
    fp = (void *)strcmp;
    fp = (void *)strcpy;
    fp = (void *)strcspn;
    fp = (void *)strerror;
    fp = (void *)strlen;
    fp = (void *)strncat;
    fp = (void *)strncmp;
    fp = (void *)strncpy;
    fp = (void *)strpbrk;
    fp = (void *)strrchr;
    fp = (void *)strspn;
    fp = (void *)strstr;
    fp = (void *)strtok;
}

/* math.h - 22 fonctions */
void test_math_decl() {
    void *fp;
    fp = (void *)acos;
    fp = (void *)asin;
    fp = (void *)atan;
    fp = (void *)atan2;
    fp = (void *)ceil;
    fp = (void *)cos;
    fp = (void *)cosh;
    fp = (void *)exp;
    fp = (void *)fabs;
    fp = (void *)floor;
    fp = (void *)fmod;
    fp = (void *)frexp;
    fp = (void *)ldexp;
    fp = (void *)log;
    fp = (void *)log10;
    fp = (void *)modf;
    fp = (void *)pow;
    fp = (void *)sin;
    fp = (void *)sinh;
    fp = (void *)sqrt;
    fp = (void *)tan;
    fp = (void *)tanh;
}

/* time.h - 9 fonctions */
void test_time_decl() {
    void *fp;
    fp = (void *)asctime;
    fp = (void *)clock;
    fp = (void *)ctime;
    fp = (void *)difftime;
    fp = (void *)gmtime;
    fp = (void *)localtime;
    fp = (void *)mktime;
    fp = (void *)strftime;
    fp = (void *)time;
}

/* ctype.h - 13 fonctions */
void test_ctype_decl() {
    void *fp;
    fp = (void *)isalnum;
    fp = (void *)isalpha;
    fp = (void *)iscntrl;
    fp = (void *)isdigit;
    fp = (void *)isgraph;
    fp = (void *)islower;
    fp = (void *)isprint;
    fp = (void *)ispunct;
    fp = (void *)isspace;
    fp = (void *)isupper;
    fp = (void *)isxdigit;
    fp = (void *)tolower;
    fp = (void *)toupper;
}

/* signal.h - 2 fonctions */
void test_signal_decl() {
    void *fp;
    fp = (void *)raise;
    fp = (void *)signal;
}

/* setjmp.h - 2 fonctions */
void test_setjmp_decl() {
    void *fp;
    fp = (void *)longjmp;
    fp = (void *)setjmp;
}

int main() {
    printf("=== Test 136 fonctions C standard built-in ===\n");
    printf("Toutes les fonctions sont acceptees par le compilateur.\n");
    printf("builtin_all: OK\n");
    return 0;
}
