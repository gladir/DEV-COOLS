/* Test boucle for avec break et continue */

int test_for_with_control() {
    int i, sum;
    sum = 0;
    
    for (i = 1; i <= 10; i = i + 1) {
        if (i == 5) {
            continue;
        }
        if (i == 8) {
            break;
        }
        sum = sum + i;
    }
    
    return sum;
}

int main() {
    return test_for_with_control();
}
