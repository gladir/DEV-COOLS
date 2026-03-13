// test_template.cpp - Test TODO 22: Templates (basique)
// Tests: template functions, template classes,
//        explicit instantiation, implicit instantiation

// Fonction template : maximum de deux valeurs
template<typename T>
T tmax(T a, T b) {
    if (a > b) {
        return a;
    }
    return b;
}

// Fonction template : minimum de deux valeurs
template<typename T>
T tmin(T a, T b) {
    if (a < b) {
        return a;
    }
    return b;
}

// Fonction template : addition
template<class U>
U tadd(U x, U y) {
    return x + y;
}

// Classe template : paire de valeurs
template<typename T>
class Pair {
public:
    T first;
    T second;

    Pair() {
        first = 0;
        second = 0;
    }

    T getFirst() {
        return first;
    }

    T getSecond() {
        return second;
    }

    T sum() {
        return first + second;
    }
};

// Classe template : boite contenant une valeur
template<typename T>
class Box {
public:
    T value;

    Box() {
        value = 0;
    }

    T get() {
        return value;
    }
};

int main() {
    // Test 1: template function implicite
    int r1;
    r1 = tmax(10, 20);
    cout << r1 << endl;

    // Test 2: template function implicite (min)
    int r2;
    r2 = tmin(5, 3);
    cout << r2 << endl;

    // Test 3: template function explicite
    int r3;
    r3 = tmax<int>(42, 7);
    cout << r3 << endl;

    // Test 4: template function add
    int r4;
    r4 = tadd(100, 200);
    cout << r4 << endl;

    // Test 5: template class Pair
    Pair<int> p;
    p.first = 10;
    p.second = 20;
    cout << p.sum() << endl;

    // Test 6: template class Box
    Box<int> b;
    b.value = 99;
    cout << b.get() << endl;

    return 0;
}
