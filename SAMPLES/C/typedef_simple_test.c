/* Test simple des typedef en C pour le compilateur CC09 */

typedef int my_integer;
typedef char my_char;
typedef unsigned int my_uint;

my_integer main() {
    my_integer a = 42;
    my_char c = 'A';
    my_uint b = 255;
    
    return a + c + b;
}
