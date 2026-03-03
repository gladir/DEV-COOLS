/* Test complet des typedef avec différents types */

/* Typedef de base */
typedef unsigned char byte;
typedef unsigned int word;
typedef int size_type;

/* Typedef de pointeurs */
typedef int* int_pointer;
typedef byte* byte_pointer;

/* Typedef de fonctions (simplifié) */
typedef int func_type;

/* Typedef imbriqués */
typedef size_type array_size;
typedef array_size big_size;

int main() {
    /* Utilisation des typedef de base */
    byte b = 255;
    word w = 65535;
    size_type s = 42;
    
    /* Utilisation des typedef de pointeurs */
    int value = 100;
    int_pointer ip = &value;
    
    /* Utilisation des typedef imbriqués */
    big_size size = 1024;
    
    return b + w + s + *ip + size;
}
