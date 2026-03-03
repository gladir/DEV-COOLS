/* Test des instructions return */

int test_return_value() {
    return 42;
}

int test_return_expr() {
    int x = 10;
    return x + 5;
}

void test_return_void() {
    int y = 20;
    return;
}

int main() {
    int result1 = test_return_value();
    int result2 = test_return_expr();
    test_return_void();
    return 0;
}
