/* Test TODO 19 : structures et unions */

struct Point {
    int x;
    int y;
};

union IntOrChar {
    int i;
    int c;
};

struct Point g_pt;

int main() {
    struct Point p;
    struct Point q;
    union IntOrChar u;
    int r;

    /* Affectation de champs struct */
    p.x = 10;
    p.y = 20;

    /* Lecture de champs struct */
    r = p.x;
    r = p.y;

    /* Deuxieme struct */
    q.x = p.x;
    q.y = 42;

    /* Union : tous les champs a offset 0 */
    u.i = 100;
    r = u.c;

    /* Struct globale */
    g_pt.x = 7;
    g_pt.y = 8;

    return 0;
}
