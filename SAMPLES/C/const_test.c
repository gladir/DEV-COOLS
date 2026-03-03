void test() {
    const int x = 5;
    int y = 10;
    
    y = 20;  // Should work - regular variable
    x = 30;  // Should fail - const variable
}
