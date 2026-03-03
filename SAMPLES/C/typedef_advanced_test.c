/* Test des typedef avancés avec pointeurs et tableaux */

typedef int* int_ptr;
typedef char string[32];
typedef struct point { int x; int y; } point_t;

int main() {
    int_ptr ptr;
    string name = "test";
    point_t origin = {0, 0};
    
    int value = 100;
    ptr = &value;
    
    return *ptr + origin.x + origin.y;
}
