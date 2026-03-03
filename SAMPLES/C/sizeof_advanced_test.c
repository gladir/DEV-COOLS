/* Test avancé de sizeof avec types complexes */

struct Point {
    int x;
    int y;
};

int main()
{
    int result;
    int arr[5];
    struct Point p;
    int *ptr;
    char str[20];
    
    /* Tests sur types de base */
    result = sizeof(int);        /* 2 octets sur 6809 */
    result = sizeof(char);       /* 1 octet */
    result = sizeof(void*);      /* 2 octets (pointeur) */
    
    /* Tests sur tableaux */
    result = sizeof(arr);        /* 5 * 2 = 10 octets */
    result = sizeof(str);        /* 20 * 1 = 20 octets */
    
    /* Tests sur structures */
    result = sizeof(struct Point); /* 2 + 2 = 4 octets */
    result = sizeof(p);          /* 4 octets */
    
    /* Tests sur pointeurs */
    result = sizeof(ptr);        /* 2 octets */
    result = sizeof(*ptr);       /* 2 octets (taille de int) */
    
    /* Tests sur expressions */
    result = sizeof(arr[0]);     /* 2 octets (int) */
    result = sizeof(p.x);        /* 2 octets (int) */
    result = sizeof(1 + 2);      /* 2 octets (résultat int) */
    
    /* Tests avec cast */
    result = sizeof((char*)ptr); /* 2 octets (pointeur) */
    result = sizeof((char)result); /* 1 octet (char) */
    
    return 0;
}
