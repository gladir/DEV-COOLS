/* Test des structures de contrôle */
int x, y, i;

x = 10;
y = 5;

if (x > y) {
    x = x + 1;
} else {
    x = x - 1;
}

while (x > 0) {
    x = x - 1;
}

for (i = 0; i < 5; i++) {
    y = y + 1;
}

if (y == 10) {
    return y;
}
