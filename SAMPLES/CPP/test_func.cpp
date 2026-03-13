// test_func.cpp - Test TODO 18: Functions and Prototypes
// Tests: function declaration, parameters, return, calls, prototype

// Prototype (forward declaration)
int square(int x);

// Simple function with no params
int get_value() {
    return 42;
}

// Function with one parameter
int double_it(int x) {
    return x + x;
}

// Function with two parameters
int add(int a, int b) {
    return a + b;
}

// Function calling other functions
int compute() {
    int a = get_value();
    int b = double_it(5);
    int c = add(a, b);
    return c;
}

// Implementation of prototype
int square(int x) {
    return x * x;
}

int main() {
    int v = get_value();
    cout << v << endl;

    int d = double_it(7);
    cout << d << endl;

    int s = add(10, 20);
    cout << s << endl;

    int sq = square(6);
    cout << sq << endl;

    int r = compute();
    cout << r << endl;

    return 0;
}
