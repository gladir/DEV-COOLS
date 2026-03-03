public class test09_array {
    public static void main(String[] args) {
        int[] tab = new int[5];
        int i;
        int sum;

        tab[0] = 10;
        tab[1] = 20;
        tab[2] = 30;
        tab[3] = 40;
        tab[4] = 50;

        sum = 0;
        for (i = 0; i < 5; i++) {
            sum += tab[i];
        }
        System.out.println(sum);

        for (int x : tab) {
            System.out.println(x);
        }

        tab[2] = 99;
        System.out.println(tab[2]);
    }
}
