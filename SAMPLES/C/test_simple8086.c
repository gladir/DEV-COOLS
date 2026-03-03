// Test complet pour CC8086 sans include
int global_var = 42;

void simple_function(int param) {
    int local_var = 10;
    return;
}

int main() {
    int x = 5;
    char c = 'A';
    int *ptr;
    int result = x + global_var;
    
    if (x > 0) {
        x = x + 1;
    } 
    
    return result;
}
