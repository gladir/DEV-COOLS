public class test06_for {
    public static void main(String[] args) {
        int i;
        int j;
        int sum;

        sum = 0;
        for (i = 0; i < 5; i++) {
            sum += i;
        }
        System.out.println(sum);

        sum = 0;
        for (i = 1; i <= 3; i++) {
            for (j = 1; j <= 3; j++) {
                sum += i * j;
            }
        }
        System.out.println(sum);

        for (i = 10; i > 0; i--) {
            if (i == 5) {
                break;
            }
        }
        System.out.println(i);
    }
}
