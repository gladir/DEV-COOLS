// Test complet pour CC8086
#include <stdio.h>

int global_var = 42;

void simple_function(int param) {
    int local_var = 10;
    return;
}

int main() {
    int x = 5;
    char c = 'A';
    int *ptr = &x;
    int result = x + global_var;
    
    simple_function(result);
    
    if (x > 0) {
        x = x + 1;
    } else {
        x = x - 1;
    }
    
    while (x < 10) {
        x = x * 2;
    }
    
    return result;
}
