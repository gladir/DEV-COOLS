/* control.cpp - if/else, switch, while, for, do-while */

int main() {
    int x = 10;

    /* if/else */
    if (x > 5) {
        cout << 1 << endl;
    } else {
        cout << 0 << endl;
    }

    /* switch */
    switch (x) {
        case 10:
            cout << 10 << endl;
            break;
        case 20:
            cout << 20 << endl;
            break;
        default:
            cout << 0 << endl;
            break;
    }

    /* while */
    int i = 0;
    while (i < 3) {
        cout << i << endl;
        i++;
    }

    /* for */
    for (int j = 0; j < 3; j++) {
        cout << j << endl;
    }

    /* do-while */
    int k = 0;
    do {
        cout << k << endl;
        k++;
    } while (k < 3);

    return 0;
}
