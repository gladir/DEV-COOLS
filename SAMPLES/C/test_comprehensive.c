// Test complet des fonctionnalités CCJASMIN
int main() {
    // Test des variables et constantes
    int a = 10;
    int b = 20;
    int c = 0;
    
    // Test des opérations arithmétiques
    c = a + b;          // Addition
    c = a - b;          // Soustraction  
    c = a * b;          // Multiplication
    c = a / b;          // Division
    c = a % b;          // Modulo
    
    // Test des expressions complexes
    c = a + b * 2 - 3;
    
    // Test des comparaisons
    if (a > b) {
        c = 1;
    }
    
    if (a == b) {
        c = 2;
    }
    
    // Test des boucles
    int i = 0;
    while (i < 5) {
        i = i + 1;
    }
    
    for (i = 0; i < 3; i = i + 1) {
        c = c + i;
    }
    
    return c;
}
