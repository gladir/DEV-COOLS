int main() {
    static int counter = 0;
    volatile int timer = 100;
    return counter + timer;
}
