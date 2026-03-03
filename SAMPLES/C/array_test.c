int main() {
    int arr[5];
    int i;
    
    // Assignation aux éléments du tableau
    arr[0] = 10;
    arr[1] = 20;
    arr[2] = 30;
    arr[3] = 40;
    arr[4] = 50;
    
    // Lecture des éléments du tableau
    i = arr[2];  // devrait être 30
    
    return i;
}
