/* Test des boucles for */

int test_for_basic() {
    int i, sum;
    sum = 0;
    
    for (i = 1; i <= 10; i = i + 1) {
        sum = sum + i;
    }
    
    return sum;
}

int test_for_complex() {
    int i, j, result;
    result = 0;
    
    for (i = 1; i < 5; i = i + 1) {
        for (j = 1; j < 3; j = j + 1) {
            result = result + i * j;
        }
    }
    
    return result;
}

int main() {
    int a, b;
    
    a = test_for_basic();
    b = test_for_complex(); 
    
    return a + b;
}
