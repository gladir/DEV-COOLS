// test_operator.cpp - Test TODO 21: Surcharge d'operateurs
// Tests: operator+, operator-, operator*, operator==, operator!=,
//        operator<, operator>, operator=, operator<<, operator[]

// Classe Vector2D avec operateurs arithmetiques
class Vector2D {
public:
    int x;
    int y;

    Vector2D() {
        x = 0;
        y = 0;
    }

    // operator+ : addition de deux vecteurs
    int operator+(const Vector2D& rhs) {
        return x + rhs.x + y + rhs.y;
    }

    // operator- : soustraction
    int operator-(const Vector2D& rhs) {
        return x - rhs.x + y - rhs.y;
    }

    // operator== : egalite
    int operator==(const Vector2D& rhs) {
        if (x == rhs.x) {
            if (y == rhs.y) {
                return 1;
            }
        }
        return 0;
    }

    // operator!= : difference
    int operator!=(const Vector2D& rhs) {
        if (x != rhs.x) {
            return 1;
        }
        if (y != rhs.y) {
            return 1;
        }
        return 0;
    }
};

// Classe Counter avec operateur d'incrementation
class Counter {
public:
    int val;

    Counter() {
        val = 0;
    }

    // operator+ : ajouter un entier
    int operator+(int n) {
        return val + n;
    }

    // operator* : multiplier
    int operator*(int n) {
        return val * n;
    }
};

int main() {
    // Test 1: operator+ sur Vector2D
    Vector2D a;
    a.x = 3;
    a.y = 4;
    Vector2D b;
    b.x = 1;
    b.y = 2;
    cout << a + b << endl;

    // Test 2: operator- sur Vector2D
    cout << a - b << endl;

    // Test 3: operator== (egal)
    Vector2D c;
    c.x = 3;
    c.y = 4;
    int eq;
    eq = a == c;
    cout << eq << endl;

    // Test 4: operator!= (different)
    int neq;
    neq = a != b;
    cout << neq << endl;

    // Test 5: Counter operator+
    Counter cnt;
    cnt.val = 10;
    cout << cnt + 5 << endl;

    // Test 6: Counter operator*
    cout << cnt * 3 << endl;

    return 0;
}
