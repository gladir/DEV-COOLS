/* templates.cpp - fonctions et classes template */

template<typename T>
T maxi(T a, T b) {
    if (a > b)
        return a;
    return b;
}

int main() {
    int x = maxi(3, 7);
    cout << x << endl;

    int y = maxi(10, 2);
    cout << y << endl;

    return 0;
}
