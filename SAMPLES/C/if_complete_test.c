/* Test complet des instructions if/else */
int a, b, c, result;

void main() {
    a = 10;
    b = 5;
    c = 15;
    
    /* Test if simple */
    if (a > b) {
        result = 1;
    }
    
    /* Test if/else */
    if (b > c) {
        result = 2;
    } else {
        result = 3;
    }
    
    /* Test if imbriqué */
    if (a > b) {
        if (c > a) {
            result = 4;
        } else {
            result = 5;
        }
    }
    
    /* Test avec différents opérateurs */
    if (a == 10) result = 6;
    if (b != 3) result = 7;  
    if (c >= 15) result = 8;
    if (b <= 10) result = 9;
}
