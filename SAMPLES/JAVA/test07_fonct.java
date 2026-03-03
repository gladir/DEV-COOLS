public class test07_fonct {
    public static int add(int a, int b) {
        return a + b;
    }

    public static int max(int a, int b) {
        if (a > b) {
            return a;
        }
        return b;
    }

    public static int square(int n) {
        return n * n;
    }

    public static void printTwice(int n) {
        System.out.println(n);
        System.out.println(n);
    }

    public static void main(String[] args) {
        int r;

        r = add(3, 7);
        System.out.println(r);

        r = max(10, 20);
        System.out.println(r);

        r = max(99, 42);
        System.out.println(r);

        r = square(6);
        System.out.println(r);

        printTwice(5);

        r = add(square(2), square(3));
        System.out.println(r);
    }
}
