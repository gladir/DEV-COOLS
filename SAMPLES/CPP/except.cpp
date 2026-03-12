/* except.cpp - try/catch/throw, catch(...) */

int divide(int a, int b) {
    if (b == 0)
        throw 1;
    return a / b;
}

int main() {
    int result = 0;

    try {
        result = divide(10, 2);
        cout << result << endl;
    } catch (int e) {
        cout << 0 << endl;
    }

    try {
        result = divide(10, 0);
        cout << result << endl;
    } catch (...) {
        cout << 99 << endl;
    }

    return 0;
}
