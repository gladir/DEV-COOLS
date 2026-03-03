/* Test complet des types long avec conversions */

typedef long long_t;
typedef unsigned long ulong_t;

long_t global_long = 123456L;
ulong_t global_ulong = 987654UL;

int main() {
    /* Variables locales */
    long local_long = -50000L;
    unsigned long local_ulong = 4000000000UL;
    
    /* Conversions */
    int from_long = (int)local_long;
    char from_long_to_char = (char)local_long;
    long from_int = (long)from_long;
    
    /* Opérations arithmétiques */
    long sum = global_long + local_long;
    long diff = global_long - local_long;
    long prod = global_long * 2L;
    
    /* Comparaisons */
    if (sum > diff) {
        return 1;
    }
    
    if (prod < 0L) {
        return 2;
    }
    
    return 0;
}
