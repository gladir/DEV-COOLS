// test_iostream.cpp - Test TODO 13 : entrees/sorties (iostream)
// cout << chaines, nombres, endl, expressions

int main() {
    // --- cout avec chaine litterale ---
    cout << "Hello, World!";
    cout << endl;

    // --- cout avec nombre ---
    int x = 42;
    cout << x;
    cout << endl;

    // --- cout chaine ---
    cout << "Valeur de x = ";
    cout << x;
    cout << '\n';

    // --- cout enchaine ---
    cout << "Test: " << 123 << endl;

    // --- cout avec expression ---
    int a = 10;
    int b = 3;
    cout << "a + b = ";
    cout << a + b;
    cout << endl;

    // --- cout avec caractere ---
    cout << '*';
    cout << endl;

    // --- cout avec zero ---
    cout << 0;
    cout << endl;

    // --- cout avec negatif ---
    int neg = -42;
    cout << neg;
    cout << endl;

    return 0;
}
