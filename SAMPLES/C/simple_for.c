/* Test for simple */

int main() {
    int i;
    
    for (i = 0; i < 5; i = i + 1) {
        i = i + 0; // instruction simple
    }
    
    return i;
}
