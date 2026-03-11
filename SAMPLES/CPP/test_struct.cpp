// test_struct.cpp - Test TODO 17: Structures and Unions
// Tests: declaration, field access, pointer access, init

struct Point {
    int x;
    int y;
};

int main() {
    // Struct variable with initializer
    Point p1 = {10, 20};
    cout << p1.x << endl;
    cout << p1.y << endl;

    // Field assignment
    Point p2;
    p2.x = 30;
    p2.y = 40;
    cout << p2.x << endl;
    cout << p2.y << endl;

    // Pointer to struct
    Point *ptr = &p1;
    cout << ptr->x << endl;
    cout << ptr->y << endl;

    // Struct with more fields
    struct Rect {
        int x;
        int y;
        int w;
        int h;
    };

    Rect r = {1, 2, 3, 4};
    cout << r.w << endl;
    cout << r.h << endl;

    return 0;
}
