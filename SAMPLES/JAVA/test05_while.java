public class test05_while {
    public static void main(String[] args) {
        int i;
        int sum;

        i = 0;
        sum = 0;
        while (i < 10) {
            sum += i;
            i++;
        }
        System.out.println(sum);

        i = 0;
        while (i < 20) {
            if (i == 5) {
                i++;
                continue;
            }
            if (i == 10) {
                break;
            }
            i++;
        }
        System.out.println(i);
    }
}
