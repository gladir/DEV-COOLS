import java.util.*;
import java.math.*;
public class Test09_Algos {
    static class Matrix {
        final double[][] a; final int n, m;
        Matrix(int n, int m) { this.n = n; this.m = m; a = new double[n][m]; }
        Matrix mul(Matrix o) {
            Matrix r = new Matrix(n, o.m);
            for (int i = 0; i < n; i++) for (int j = 0; j < o.m; j++) { double s = 0; for (int k = 0; k < m; k++) s += a[i][k] * o.a[k][j]; r.a[i][j] = s; }
            return r;
        }
    }
    static boolean isPrime(int n) { if (n < 2) return false; for (int i = 2; (long) i * i <= n; i++) if (n % i == 0) return false; return true; }
    static long gcd(long a, long b) { return b == 0 ? a : gcd(b, a % b); }
    static void hanoi(int n, char f, char t, char v, List<String> out) { if (n == 0) return; hanoi(n - 1, f, v, t, out); out.add(f + ">" + t); hanoi(n - 1, v, t, f, out); }
    static int[] sieve(int n) { boolean[] c = new boolean[n + 1]; List<Integer> ps = new ArrayList<>(); for (int i = 2; i <= n; i++) { if (!c[i]) { ps.add(i); for (long j = (long) i * i; j <= n; j += i) c[(int) j] = true; } } return ps.stream().mapToInt(Integer::intValue).toArray(); }
    static String rev(String s) { return s.isEmpty() ? s : rev(s.substring(1)) + s.charAt(0); }
    static void bubble(int[] a) { for (int i = 0; i < a.length; i++) for (int j = 0; j + 1 < a.length - i; j++) if (a[j] > a[j + 1]) { int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t; } }
    static int binsearch(int[] a, int k) { int lo = 0, hi = a.length - 1; while (lo <= hi) { int mid = (lo + hi) >>> 1; if (a[mid] == k) return mid; else if (a[mid] < k) lo = mid + 1; else hi = mid - 1; } return -1; }
    public static void main(String[] args) {
        Matrix x = new Matrix(2, 2); x.a[0][0] = 1; x.a[0][1] = 2; x.a[1][0] = 3; x.a[1][1] = 4;
        Matrix y = x.mul(x);
        System.out.println(Arrays.toString(y.a[0]) + Arrays.toString(y.a[1]));
        int cnt = 0; for (int i = 0; i < 100; i++) if (isPrime(i)) cnt++;
        System.out.println(cnt + " " + gcd(1071, 462) + " " + Arrays.toString(sieve(30)));
        List<String> mv = new ArrayList<>(); hanoi(3, 'A', 'C', 'B', mv);
        System.out.println(mv.size() + " " + mv);
        System.out.println(rev("hello") + " " + new StringBuilder("abc").reverse());
        int[] arr = {5, 3, 9, 1, 7}; bubble(arr);
        System.out.println(Arrays.toString(arr) + binsearch(arr, 7) + binsearch(arr, 4));
        BigInteger f = BigInteger.ONE;
        for (int i = 2; i <= 25; i++) f = f.multiply(BigInteger.valueOf(i));
        System.out.println(f + " " + f.bitLength());
        BigDecimal bd = new BigDecimal("10").divide(new BigDecimal("3"), 5, RoundingMode.HALF_UP);
        System.out.println(bd);
        long h = 7; for (char ch : "hash me".toCharArray()) h = h * 31 + ch;
        System.out.println(h + " " + (h ^ (h >>> 16)) + " " + Long.toHexString(h));
        System.out.println(Integer.MIN_VALUE + " " + Math.abs(Integer.MIN_VALUE) + " " + (byte) 130 + " " + (int) 3.99e10 + " " + (long) -2.5 + " " + (int) Double.NaN + " " + (char) 66);
        System.out.println(1.0f / 3 + " " + 2 / 3.0 + " " + 1e-5 + " " + 100.0 + " " + 1.0E7 + " " + (float) 1e10);
        System.out.println(0.1 + 0.2 + " " + (0.1f + 0.2f) + " " + 5 % -3 + " " + -5 % 3 + " " + 5.5 % 2);
        System.out.println(Long.MAX_VALUE / -1 + " " + (Integer.MIN_VALUE / -1) + " " + (7 >> 1) + (7 << 30) + (7L << 62));
        Random rnd = new Random(42);
        System.out.println(rnd.nextInt(100) + " " + rnd.nextInt(100) + " " + rnd.nextDouble());
        String str = "a,b;c  d";
        System.out.println(Arrays.toString(str.split("[,; ]+")) + " " + "  trim ".trim() + "|" + "x".repeat(3) + "|" + "Hello".chars().sum());
        System.out.println(String.valueOf(new char[]{'o', 'k'}) + " " + "abc".compareTo("abd") + " " + "A".equalsIgnoreCase("a") + " " + "mississippi".lastIndexOf("ss") + " " + "a-b".contains("-"));
    }
}
