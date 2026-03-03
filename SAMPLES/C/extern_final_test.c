extern int global_counter;
extern char status_flag;
extern unsigned int config_value;
extern char *error_message;
extern int *data_buffer;
extern int score_array[100];
extern char name_buffer[256];

void main() {
    extern int local_extern_var;
    extern char local_extern_char;
}

static int internal_var;
extern int shared_var;
