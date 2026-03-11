// test_primary.cpp - Test TODO 11 : expressions primaires C++
// Appel de fonction, sizeof, new, delete, dereference, adresse,
// acces index, acces membre, this, static_cast, casts

int result;
int g_val = 99;

int add(int a, int b) {
    return a + b;
}

int square(int x) {
    return x * x;
}

int negate(int n) {
    return -n;
}

int main() {
    // --- Literals et sizeof ---
    int a = 42;
    int b = sizeof(int);
    int c = sizeof(char);
    int d = sizeof(long);

    // --- sizeof sur pointeur ---
    int e = sizeof(int*);

    // --- new et delete ---
    int* p = new int;
    delete p;

    // --- new[] et delete[] ---
    int* arr = new int[10];
    delete[] arr;

    // --- Dereferencement et adresse ---
    int val = 100;
    int* ptr = &val;
    int deref = *ptr;

    // --- Pre/post increment ---
    int x = 5;
    x++;
    ++x;
    x--;
    --x;

    // --- Cast ---
    int n = (int)3;
    int m = static_cast<int>(7);

    // --- Appels de fonction ---
    int sum = add(10, 20);
    int sq = square(6);
    int neg = negate(42);

    return 0;
}
