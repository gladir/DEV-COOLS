// test_if_switch.cpp - Test TODO 14 : if / else / switch
// Compile : CPP86 test_if_switch.cpp test_if_switch.asm

int main() {
    // --- if simple ---
    int x = 5;
    if (x > 3) {
        cout << "x > 3" << endl;
    }

    // --- if / else ---
    int y = 2;
    if (y > 10) {
        cout << "grand" << endl;
    } else {
        cout << "petit" << endl;
    }

    // --- else if chain ---
    int n = 42;
    if (n > 100) {
        cout << "tres grand" << endl;
    } else if (n > 50) {
        cout << "grand" << endl;
    } else if (n > 10) {
        cout << "moyen" << endl;
    } else {
        cout << "petit" << endl;
    }

    // --- if avec expression ---
    int a = 3;
    int b = 3;
    if (a == b) {
        cout << "egal" << endl;
    }

    // --- switch simple ---
    int day = 3;
    switch (day) {
        case 1:
            cout << "lundi" << endl;
            break;
        case 2:
            cout << "mardi" << endl;
            break;
        case 3:
            cout << "mercredi" << endl;
            break;
        default:
            cout << "autre" << endl;
            break;
    }

    return 0;
}
