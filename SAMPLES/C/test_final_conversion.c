int test_function() {
    int x = 42;
    int y = 0;
    
    if (x > 0) {
        y = x * 2;
    }
    
    for (int i = 0; i < 5; i++) {
        y = y + i;
    }
    
    while (y > 0) {
        y = y - 1;
        if (y == 25) break;
    }
    
    return y;
}
