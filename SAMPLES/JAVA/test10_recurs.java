public class test10_recurs {
    public static int fact(int n) {
        if (n <= 1) {
            return 1;
        }
        return n * fact(n - 1);
    }

    public static int fib(int n) {
        if (n <= 1) {
            return n;
        }
        return fib(n - 1) + fib(n - 2);
    }

    public static void main(String[] args) {
        int r;

        r = fact(1);
        System.out.println(r);

        r = fact(5);
        System.out.println(r);

        r = fact(10);
        System.out.println(r);

        r = fib(0);
        System.out.println(r);

        r = fib(7);
        System.out.println(r);
    }
}
