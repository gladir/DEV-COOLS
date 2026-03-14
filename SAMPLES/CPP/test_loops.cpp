// test_loops.cpp - Test TODO 15 : while / do-while / for / break / continue
// Compile : CPP86 test_loops.cpp test_loops.asm

int main() {
    // --- while simple : somme 1..5 = 15 ---
    int sum = 0;
    int i = 1;
    while (i <= 5) {
        sum = sum + i;
        i = i + 1;
    }
    cout << "while sum = " << sum << endl;

    // --- do-while : somme 1..3 = 6 ---
    int s2 = 0;
    int j = 1;
    do {
        s2 = s2 + j;
        j = j + 1;
    } while (j <= 3);
    cout << "do-while sum = " << s2 << endl;

    // --- for classique : somme 0..4 = 10 ---
    int s3 = 0;
    for (int k = 0; k < 5; k = k + 1) {
        s3 = s3 + k;
    }
    cout << "for sum = " << s3 << endl;

    // --- break dans while ---
    int s4 = 0;
    int m = 0;
    while (m < 100) {
        if (m >= 3) {
            break;
        }
        s4 = s4 + m;
        m = m + 1;
    }
    cout << "break sum = " << s4 << endl;

    // --- continue dans for ---
    int s5 = 0;
    for (int p = 0; p < 5; p = p + 1) {
        if (p == 2) {
            continue;
        }
        s5 = s5 + p;
    }
    cout << "continue sum = " << s5 << endl;

    return 0;
}
