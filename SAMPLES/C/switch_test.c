/* Test du support switch/case/default */

int test_switch(int x) {
    int result = 0;
    
    switch (x) {
        case 1:
            result = 10;
            break;
        case 2:
            result = 20;
            break;
        case 3:
        case 4:
            result = 30; /* Test des cases qui tombent */
            break;
        default:
            result = 99;
            break;
    }
    
    return result;
}

int nested_switch(int a, int b) {
    int result = 0;
    
    switch (a) {
        case 1:
            switch (b) {
                case 10:
                    result = 100;
                    break;
                case 20:
                    result = 200;
                    break;
                default:
                    result = 999;
                    break;
            }
            break;
        case 2:
            result = 2000;
            break;
        default:
            result = 9999;
            break;
    }
    
    return result;
}
