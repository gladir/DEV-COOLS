/* Test du support static dans CC09 */

static int global_counter = 0;
int normal_var = 42;

static void internal_function() {
    static int call_count = 0;
    call_count++;
}

void public_function() {
    static int local_static = 10;
    int local_auto = 20;
    local_static++;
}

int main() {
    static int main_static = 100;
    int main_auto = 200;
    
    global_counter = 5;
    main_static = 150;
    
    public_function();
    internal_function();
    
    return 0;
}
