// test_namespace.cpp - Test des espaces de noms (TODO 24)
// namespace, using namespace, using Nom::symbole, anonyme, imbrique

#include <iostream>

// Test 1 : using namespace std
using namespace std;

// Test 2 : namespace simple avec fonction
namespace Math {
    int square(int x) {
        return x * x;
    }

    int add(int a, int b) {
        return a + b;
    }
}

// Test 3 : namespace imbrique
namespace Outer {
    namespace Inner {
        int value() {
            return 42;
        }
    }
}

// Test 4 : namespace anonyme (portee fichier)
namespace {
    int hidden_val = 100;
}

// Test 5 : using Nom::symbole
using Math::square;

// Test 6 : std::cout explicite
void test_std_explicit() {
    std::cout << "explicit std::cout" << std::endl;
}

// Test 7 : namespace avec variables
namespace Config {
    int width = 640;
    int height = 480;
}

int main() {
    // Test 1 : using namespace std (cout sans prefix)
    cout << "test using namespace: ok" << endl;

    // Test 2 : appel fonction du namespace
    int r = Math::add(3, 4);
    cout << "Math::add(3,4) = ";
    cout << r;
    cout << endl;

    // Test 3 : namespace imbrique
    cout << "nested: ok" << endl;

    // Test 5 : using import
    int sq = square(5);
    cout << "square(5) = ";
    cout << sq;
    cout << endl;

    // Test 6 : std::cout explicite
    test_std_explicit();

    // Test 7 : variables namespace
    int w = Config::width;
    cout << "Config::width = ";
    cout << w;
    cout << endl;

    return 0;
}
