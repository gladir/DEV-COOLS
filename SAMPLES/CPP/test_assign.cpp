// test_assign.cpp - Test TODO 10 : affectations et operateurs
// Compound assignments, increment/decrement, multiple declarations

int counter = 0;
const int LIMIT = 255;

int main() {
    int a = 100;
    int b = 3;
    int c;
    c = a;
    a += 10;
    b -= 1;
    a *= 2;
    b /= 2;
    c %= 7;
    int d = a & 0xFF;
    int e = b | 0x10;
    int f = c ^ 3;
    d <<= 2;
    e >>= 1;
    a++;
    b--;
    ++c;
    --d;
    int x = 1, y = 2, z = 3;
    return 0;
}
