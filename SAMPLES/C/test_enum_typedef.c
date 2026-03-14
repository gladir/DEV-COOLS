/* Test TODO 20 : enumerations et typedef */

/* Enum simple avec auto-increment */
enum color { RED, GREEN, BLUE };

/* Enum avec valeurs explicites */
enum status { OK = 0, ERR_FILE = 10, ERR_MEM = 20, ERR_NEXT };

/* Typedef de types de base */
typedef int BOOL;
typedef int INT32;

/* Typedef de struct */
struct point { int x; int y; };
typedef struct point Point;

/* Variable globale de type enum */
enum color g_color;

int main() {
    enum color c;
    enum status s;
    int r;
    BOOL flag;
    INT32 val;
    Point p;

    /* Affectation de valeurs enum */
    c = RED;
    r = c;

    c = GREEN;
    r = c;

    c = BLUE;
    r = c;

    /* Valeurs explicites */
    s = OK;
    r = s;

    s = ERR_FILE;
    r = s;

    s = ERR_MEM;
    r = s;

    s = ERR_NEXT;
    r = s;

    /* Typedef : BOOL et INT32 sont comme int */
    flag = 1;
    val = 42;

    /* Typedef de struct */
    p.x = 10;
    p.y = 20;

    /* Enum dans variable globale */
    g_color = BLUE;

    return 0;
}
