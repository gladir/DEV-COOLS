int a, b, c, result;

void main() {
    a = 10;
    b = 5;
    c = 15;
    
    if (a > b) {
        result = 1;
    }
    
    if (b > c) {
        result = 2;
    } else {
        result = 3;
    }
    
    if (a > b) {
        if (c > a) {
            result = 4;
        } else {
            result = 5;
        }
    }
    
    if (a == 10) result = 6;
    if (b != 3) result = 7;  
    if (c >= 15) result = 8;
    if (b <= 10) result = 9;
}
