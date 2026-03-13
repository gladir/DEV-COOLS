/* structs.cpp - struct, acces champs */

struct Point {
    int x;
    int y;
};

int main() {
    struct Point p;
    p.x = 10;
    p.y = 20;

    cout << p.x << endl;
    cout << p.y << endl;

    return 0;
}
