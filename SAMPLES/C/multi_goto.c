int main() {
    int x = 1;
    
    goto test1;
    x = 99;
    
test1:
    x = x + 10;
    goto end;
    x = 88;
    
test2:
    x = x + 5;
    
end:
    return x;
}
