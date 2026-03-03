/* Test complet du support volatile dans CC09 */

volatile int global_volatile;
int normal_var;

int main() {
    volatile int local_volatile;
    int local_normal;
    
    global_volatile = 5;
    local_volatile = 15;
    normal_var = 25;
    local_normal = 35;
    
    return 0;
}
