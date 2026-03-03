/* Test file for break and continue statements */

int main() {
    int i, j;
    
    /* Test break in while loop */
    i = 0;
    while (i < 10) {
        if (i == 5) {
            break;
        }
        i = i + 1;
    }
    
    /* Test continue in while loop */
    i = 0;
    while (i < 10) {
        i = i + 1;
        if (i == 3) {
            continue;
        }
    }
    
    /* Test break in for loop */
    for (i = 0; i < 10; i = i + 1) {
        if (i == 7) {
            break;
        }
    }
    
    /* Test continue in for loop */
    for (i = 0; i < 10; i = i + 1) {
        if (i == 4) {
            continue;
        }
    }
    
    /* Test nested loops with break/continue */
    for (i = 0; i < 3; i = i + 1) {
        for (j = 0; j < 3; j = j + 1) {
            if (j == 1) {
                continue;
            }
            if (i == 1 && j == 2) {
                break;
            }
        }
    }
    
    /* Test do-while with break */
    i = 0;
    do {
        if (i == 3) {
            break;
        }
        i = i + 1;
    } while (i < 10);
    
    /* Test do-while with continue */
    i = 0;
    do {
        i = i + 1;
        if (i == 2) {
            continue;
        }
    } while (i < 5);
    
    return 0;
}
