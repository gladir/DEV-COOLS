/* math.cpp - Fonctions, surcharge, recursion, return */

int add(int a, int b) {
    return a + b;
}

int mul(int a, int b) {
    return a * b;
}

int factorial(int n) {
    if (n <= 1)
        return 1;
    return n * factorial(n - 1);
}

int fib(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    int a = add(3, 4);
    int b = mul(5, 6);
    int c = factorial(5);
    int d = fib(7);
    cout << a << endl;
    cout << b << endl;
    cout << c << endl;
    cout << d << endl;
    return 0;
}
