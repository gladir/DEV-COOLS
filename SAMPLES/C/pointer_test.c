/* Test des pointeurs */
int main() {
    int x = 10;
    int *ptr;
    
    ptr = &x;    /* Opérateur adresse */
    int y = *ptr; /* Opérateur déréférencement */
    
    return 0;
}
