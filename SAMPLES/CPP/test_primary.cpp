// test_primary.cpp - Test TODO 11 : expressions primaires C++
// sizeof, new, delete, dereference, adresse,
// acces index, pre/post incr/decr, casts

int result;
int g_val = 99;

int main() {
    // --- Literals et sizeof ---
    int a = 42;
    int b = sizeof(int);
    int c = sizeof(char);
    int d = sizeof(long);

    // --- sizeof sur pointeur ---
    int e = sizeof(int*);

    // --- sizeof sur variable ---
    int f = sizeof(a);

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

    // --- Cast C style ---
    int n = (int)3;

    // --- static_cast ---
    int m = static_cast<int>(7);

    // --- Expression parenthesee ---
    int r = (a + b) * 2;

    return 0;
}
