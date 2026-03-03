/* Test complet du support extern */

/* Variables externes simples */
extern int global_counter;
extern char status_flag;
extern unsigned int config_value;

/* Pointeurs externes */
extern char *error_message;
extern int *data_buffer;
extern void *generic_pointer;

/* Tableaux externes */
extern int score_array[100];
extern char name_buffer[256];
extern double float_table[10];

/* Fonctions externes */
extern int calculate_sum(int a, int b);
extern void print_message(char *msg);
extern char *get_input_string();

/* Variables extern avec différents storage classes dans fonction */
void test_function() {
    extern int local_extern_var;
    extern char local_extern_char;
    extern int *local_extern_ptr;
    
    /* Utilisation des variables externes */
    global_counter = 42;
    status_flag = 'A';
    *data_buffer = global_counter;
}

/* Mélange extern et autres storage classes */
static int internal_var = 10;
extern int shared_var;
auto int temporary_var;

int main() {
    extern int main_extern_var;
    return 0;
}
