// test_vardecl.cpp - Test TODO 10 : variables et affectations
// Declarations globales et locales, affectations simples et composees

int g = 42;
int h;
const int MAX = 100;

int main() {
    int x = 10;
    int y = 20;
    int z;
    z = x + y;
    x = x + 1;
    y = y - 1;
    int a = 5, b = 6, c = 7;
    a += b;
    c -= 2;
    x++;
    --y;
    return 0;
}
