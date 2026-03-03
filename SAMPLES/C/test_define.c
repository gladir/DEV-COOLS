/* test_define.c - Test program for #define directive */

#define MAX_SIZE 100
#define MIN_SIZE 10
#define PI 3.14159
#define TRUE 1
#define FALSE 0
#define SQUARE(x) x * x

int main() {
    int size;
    int result;
    
    size = MAX_SIZE;
    
    if (size > MIN_SIZE) {
        result = TRUE;
    } else {
        result = FALSE;
    }
    
    return result;
}
