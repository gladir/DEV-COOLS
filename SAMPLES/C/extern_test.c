/* Test du support extern */

/* Variables externes - définies ailleurs */
extern int global_counter;
extern char* message;
extern float pi_value;

/* Variables locales pour comparaison */
int local_var = 42;
static int static_var = 100;

/* Fonction qui utilise les variables externes */
int test_extern() {
    int result;
    
    result = global_counter + local_var;
    
    return result;
}

/* Variables avec différentes classes de stockage */
extern int external_array[10];
static char internal_buffer[256];
auto int automatic_var;

int main() {
    int total;
    
    total = test_extern();
    total = total + static_var;
    
    return total;
}
