/* Test des opérations long avancées */

long add_long(long x, long y) {
    return x + y;
}

long multiply_long(long a, long b) {
    return a * b;
}

int main() {
    long a = 50000L;
    long b = 75000L;
    long result;
    
    result = add_long(a, b);
    result = multiply_long(a, b);
    
    if (result > 100000L) {
        return 1;
    }
    
    return 0;
}
