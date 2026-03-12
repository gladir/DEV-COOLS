// test_exception.cpp - Test des exceptions (TODO 23)
// try / catch / throw / catch(...)

#include <iostream>

// Test 1 : try/catch simple avec throw entier
int test_basic() {
    int result = 0;
    try {
        result = 10;
        throw 42;
        result = 99;
    } catch (int e) {
        result = e;
    }
    return result;
}

// Test 2 : catch(...)
int test_catch_all() {
    int val = 0;
    try {
        throw 7;
    } catch (...) {
        val = 1;
    }
    return val;
}

// Test 3 : catch multiples
int test_multi_catch() {
    int r = 0;
    try {
        throw 4;
    } catch (char c) {
        r = 1;
    } catch (int e) {
        r = 2;
    } catch (...) {
        r = 3;
    }
    return r;
}

// Test 4 : try/catch sans exception levee
int test_no_throw() {
    int x = 5;
    try {
        x = x + 10;
    } catch (int e) {
        x = 0;
    }
    return x;
}

// Test 5 : throw dans une fonction appelee
void do_throw() {
    throw 99;
}

int test_throw_in_func() {
    int r = 0;
    try {
        do_throw();
    } catch (int e) {
        r = e;
    }
    return r;
}

int main() {
    cout << "test_basic: ";
    cout << test_basic();
    cout << endl;

    cout << "test_catch_all: ";
    cout << test_catch_all();
    cout << endl;

    cout << "test_multi_catch: ";
    cout << test_multi_catch();
    cout << endl;

    cout << "test_no_throw: ";
    cout << test_no_throw();
    cout << endl;

    cout << "test_throw_in_func: ";
    cout << test_throw_in_func();
    cout << endl;

    return 0;
}
