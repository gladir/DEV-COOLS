/* arrays.cpp - Tableaux, pointeurs, arithmetique pointeurs */

int main() {
    int arr[5];
    arr[0] = 10;
    arr[1] = 20;
    arr[2] = 30;
    arr[3] = 40;
    arr[4] = 50;

    int sum = 0;
    for (int i = 0; i < 5; i++) {
        sum = sum + arr[i];
    }
    cout << sum << endl;

    int* p = &arr[0];
    cout << *p << endl;

    return 0;
}
