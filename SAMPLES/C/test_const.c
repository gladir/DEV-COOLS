// Test const variable checking
int main() {
    const int x = 10;
    int y = 20;
    
    // This should be allowed
    y = 30;
    
    // This should generate an error
    x = 25;
    
    return 0;
}
