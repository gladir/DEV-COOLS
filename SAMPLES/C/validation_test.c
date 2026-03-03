// Test de validation CCJASMIN - Fonctionnalités de base
int main() {
    // Test 1: Déclaration et initialisation
    int a = 15;
    int b = 7; 
    int result;
    
    // Test 2: Opérations arithmétiques de base
    result = a + b;    // Addition -> iadd
    result = a - b;    // Soustraction -> isub  
    result = a * b;    // Multiplication -> imul
    result = a / b;    // Division -> idiv
    result = a % b;    // Modulo -> irem
    
    // Test 3: Expression complexe avec priorité d'opérateurs
    result = a + b * 2 - 3;
    
    // Test 4: Assignations simples
    a = 100;
    b = result + 10;
    
    return result;
}
