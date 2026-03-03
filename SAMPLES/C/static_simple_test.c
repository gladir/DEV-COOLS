static int global_var;

int main() {
    static int local_var;
    global_var = 10;
    local_var = 20;
    return 0;
}
