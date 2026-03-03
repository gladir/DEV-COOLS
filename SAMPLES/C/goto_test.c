int main() {
    int x = 10;
    
    if (x > 5) {
        goto end_label;
    }
    
    x = 20;
    
    end_label:
    return x;
}
