package java.util;
import java.util.stream.*;
public class Random implements java.io.Serializable {
    private long seed;
    private static long seedUniquifier = 8682522807148012L;
    private double nextNextGaussian;
    private boolean haveNextNextGaussian = false;
    public Random() { this((seedUniquifier *= 1181783497276652981L) ^ System.nanoTime()); }
    public Random(long seed) { this.seed = (seed ^ 0x5DEECE66DL) & ((1L << 48) - 1); }
    public synchronized void setSeed(long seed) { this.seed = (seed ^ 0x5DEECE66DL) & ((1L << 48) - 1); haveNextNextGaussian = false; }
    protected int next(int bits) {
        seed = (seed * 0x5DEECE66DL + 0xBL) & ((1L << 48) - 1);
        return (int) (seed >>> (48 - bits));
    }
    public void nextBytes(byte[] bytes) {
        for (int i = 0, len = bytes.length; i < len; )
            for (int rnd = nextInt(), n = Math.min(len - i, 4); n-- > 0; rnd >>= 8) bytes[i++] = (byte) rnd;
    }
    public int nextInt() { return next(32); }
    public int nextInt(int bound) {
        if (bound <= 0) throw new IllegalArgumentException("bound must be positive");
        int r = next(31);
        int m = bound - 1;
        if ((bound & m) == 0) r = (int) ((bound * (long) r) >> 31);
        else { for (int u = r; u - (r = u % bound) + m < 0; u = next(31)) ; }
        return r;
    }
    public int nextInt(int origin, int bound) {
        if (origin >= bound) throw new IllegalArgumentException("bound must be greater than origin");
        int r = nextInt();
        int n = bound - origin, m = n - 1;
        if ((n & m) == 0) r = (r & m) + origin;
        else if (n > 0) { for (int u = r >>> 1; u + m - (r = u % n) < 0; u = nextInt() >>> 1) ; r += origin; }
        else { while (r < origin || r >= bound) r = nextInt(); }
        return r;
    }
    public long nextLong() { return ((long) (next(32)) << 32) + next(32); }
    public boolean nextBoolean() { return next(1) != 0; }
    public float nextFloat() { return next(24) / ((float) (1 << 24)); }
    public double nextDouble() { return (((long) (next(26)) << 27) + next(27)) * 0x1.0p-53; }
    public double nextDouble(double bound) { return nextDouble() * bound; }
    public double nextDouble(double origin, double bound) { return origin + nextDouble() * (bound - origin); }
    public synchronized double nextGaussian() {
        if (haveNextNextGaussian) { haveNextNextGaussian = false; return nextNextGaussian; }
        double v1, v2, s;
        do {
            v1 = 2 * nextDouble() - 1;
            v2 = 2 * nextDouble() - 1;
            s = v1 * v1 + v2 * v2;
        } while (s >= 1 || s == 0);
        double multiplier = StrictMath.sqrt(-2 * StrictMath.log(s) / s);
        nextNextGaussian = v2 * multiplier;
        haveNextNextGaussian = true;
        return v1 * multiplier;
    }
    public IntStream ints(long n, int origin, int bound) {
        int[] a = new int[(int) n];
        for (int i = 0; i < a.length; i++) a[i] = nextInt(origin, bound);
        return IntStream.of(a);
    }
    public IntStream ints(long n) {
        int[] a = new int[(int) n];
        for (int i = 0; i < a.length; i++) a[i] = nextInt();
        return IntStream.of(a);
    }
    public DoubleStream doubles(long n) {
        double[] a = new double[(int) n];
        for (int i = 0; i < a.length; i++) a[i] = nextDouble();
        return DoubleStream.of(a);
    }
}
