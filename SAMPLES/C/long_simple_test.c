/* Test simple des types long en C pour le compilateur CC09 */

long a;
unsigned long b;
long int c;

int main() {
    long x = 100000L;
    unsigned long y = 200000UL;
    
    a = x;
    b = y;
    c = x + y;
    
    return 0;
}
