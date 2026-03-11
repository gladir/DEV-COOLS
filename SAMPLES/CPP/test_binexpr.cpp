// test_binexpr.cpp - Test TODO 12 : expressions binaires C++
// Arithmetique, bits, comparaisons, logique, ternaire, virgule

int main() {
    // --- Arithmetique entiere ---
    int a = 10 + 3;
    int b = 10 - 3;
    int c = 4 * 5;
    int d = 20 / 4;
    int e = 17 % 5;

    // --- Operateurs bit a bit ---
    int f = 0xFF & 0x0F;
    int g = 0xF0 | 0x0F;
    int h = 0xFF ^ 0x0F;
    int i = 1 << 4;
    int j = 32 >> 2;

    // --- Comparaison ---
    int k = 5 == 5;
    int l = 5 != 3;
    int m = 3 < 5;
    int n = 5 <= 5;
    int o = 7 > 3;
    int p = 3 >= 3;

    // --- Logique court-circuit ---
    int q = 1 && 1;
    int r = 1 && 0;
    int s = 0 || 1;
    int t = 0 || 0;

    // --- Ternaire ---
    int u = 1 ? 42 : 99;
    int v = 0 ? 42 : 99;

    // --- Precedence mixte ---
    int w = 2 + 3 * 4;
    int x = (2 + 3) * 4;

    // --- Variables et operations ---
    int y = a + b;
    int z = y * 2 - a;

    return 0;
}
