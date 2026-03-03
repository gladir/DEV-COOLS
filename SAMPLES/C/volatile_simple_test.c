volatile int global_var;

int main() {
    volatile int local_var;
    global_var = 10;
    local_var = 20;
    return 0;
}
