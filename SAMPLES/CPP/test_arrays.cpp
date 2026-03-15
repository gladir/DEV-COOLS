// test_arrays.cpp - Test TODO 16: Arrays and Pointers
// Tests: declaration, init, subscript read/write, loops over arrays

int main() {
    // Local array with explicit size
    int a[5];
    a[0] = 10;
    a[1] = 20;
    a[2] = 30;
    a[3] = 40;
    a[4] = 50;

    // Read back via subscript
    int x = a[2];
    cout << x << endl;

    // Array with initializer list
    int b[3] = {100, 200, 300};
    cout << b[0] << endl;
    cout << b[1] << endl;
    cout << b[2] << endl;

    // Inferred size from initializer
    int c[] = {7, 8, 9};
    cout << c[0] << endl;

    // Loop over array
    int sum = 0;
    int i = 0;
    while (i < 5) {
        sum = sum + a[i];
        i++;
    }
    cout << sum << endl;

    // Pointer to array (array decays to pointer)
    int *p = a;
    cout << *p << endl;

    return 0;
}
