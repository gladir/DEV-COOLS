public class test04_cond {
    public static void main(String[] args) {
        int a;
        int b;
        boolean r;

        a = 10;
        b = 20;

        if (a == b) {
            System.out.println("egal");
        } else {
            System.out.println("different");
        }

        if (a != b) {
            System.out.println("non egal");
        }

        if (a < b) {
            System.out.println("a plus petit");
        }

        if (a > b) {
            System.out.println("a plus grand");
        } else {
            System.out.println("a pas plus grand");
        }

        if (a <= 10) {
            System.out.println("a <= 10");
        }

        if (b >= 20) {
            System.out.println("b >= 20");
        }

        r = (a < b) && (b > 0);
        System.out.println(r);

        r = (a > b) || (b == 20);
        System.out.println(r);

        r = !(a == b);
        System.out.println(r);
    }
}
