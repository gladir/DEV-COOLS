package java.lang;
public final class Long extends Number implements Comparable<Long> {
    public static final long MIN_VALUE = 0x8000000000000000L;
    public static final long MAX_VALUE = 0x7fffffffffffffffL;
    public static final int SIZE = 64;
    public static final int BYTES = 8;
    public static final Class<Long> TYPE = (Class<Long>) Class.getPrimitiveClass("long");
    private final long value;
    private static final Long[] cache = new Long[256];
    public Long(long value) { this.value = value; }
    public Long(String s) { this.value = parseLong(s, 10); }
    public static Long valueOf(long l) {
        if (l >= -128 && l <= 127) {
            Long r = cache[(int) l + 128];
            if (r == null) { r = new Long(l); cache[(int) l + 128] = r; }
            return r;
        }
        return new Long(l);
    }
    public static Long valueOf(String s) { return valueOf(parseLong(s, 10)); }
    public static long parseLong(String s) { return parseLong(s, 10); }
    public static long parseLong(String s, int radix) {
        if (s == null) throw new NumberFormatException("Cannot parse null string: null");
        int len = s.length();
        if (len == 0) throw new NumberFormatException("For input string: \"\"");
        int i = 0;
        boolean neg = false;
        char first = s.charAt(0);
        if (first == '-' || first == '+') {
            neg = first == '-';
            i = 1;
            if (len == 1) throw new NumberFormatException("For input string: \"" + s + "\"");
        }
        long limit = neg ? MIN_VALUE : -MAX_VALUE;
        long multmin = limit / radix;
        long result = 0;
        while (i < len) {
            int digit = Character.digit(s.charAt(i++), radix);
            if (digit < 0 || result < multmin) throw new NumberFormatException("For input string: \"" + s + "\"" + (radix != 10 ? " under radix " + radix : ""));
            result *= radix;
            if (result < limit + digit) throw new NumberFormatException("For input string: \"" + s + "\"" + (radix != 10 ? " under radix " + radix : ""));
            result -= digit;
        }
        return neg ? result : -result;
    }
    public static native String toString(long l);
    public static String toString(long i, int radix) {
        if (radix < 2 || radix > 36) radix = 10;
        if (radix == 10) return toString(i);
        if (i == 0) return "0";
        char[] buf = new char[65];
        int pos = 65;
        boolean neg = i < 0;
        if (!neg) i = -i;
        while (i != 0) { buf[--pos] = Character.forDigit((int) -(i % radix), radix); i /= radix; }
        if (neg) buf[--pos] = '-';
        return new String(buf, pos, 65 - pos);
    }
    public static native String toHexString(long l);
    public static String toBinaryString(long i) { return toUnsignedString(i, 1); }
    public static String toOctalString(long i) { return toUnsignedString(i, 3); }
    private static String toUnsignedString(long i, int shift) {
        if (i == 0) return "0";
        char[] buf = new char[64];
        int pos = 64;
        long mask = (1L << shift) - 1;
        while (i != 0) { buf[--pos] = Character.forDigit((int) (i & mask), 1 << shift); i >>>= shift; }
        return new String(buf, pos, 64 - pos);
    }
    public static String toUnsignedString(long i) {
        if (i >= 0) return toString(i);
        long q = (i >>> 1) / 5;
        long r = i - q * 10;
        return toString(q) + r;
    }
    public int intValue() { return (int) value; }
    public long longValue() { return value; }
    public float floatValue() { return value; }
    public double doubleValue() { return value; }
    public int hashCode() { return (int) (value ^ (value >>> 32)); }
    public static int hashCode(long v) { return (int) (v ^ (v >>> 32)); }
    public boolean equals(Object o) { return o instanceof Long && ((Long) o).value == value; }
    public String toString() { return toString(value); }
    public int compareTo(Long o) { return compare(value, o.value); }
    public static int compare(long x, long y) { return x < y ? -1 : (x == y ? 0 : 1); }
    public static int signum(long i) { return (int) ((i >> 63) | (-i >>> 63)); }
    public static long sum(long a, long b) { return a + b; }
    public static long max(long a, long b) { return a >= b ? a : b; }
    public static long min(long a, long b) { return a <= b ? a : b; }
    public static int bitCount(long i) {
        int c = 0;
        while (i != 0) { c++; i &= i - 1; }
        return c;
    }
    public static int numberOfLeadingZeros(long i) {
        int x = (int) (i >>> 32);
        return x == 0 ? 32 + Integer.numberOfLeadingZeros((int) i) : Integer.numberOfLeadingZeros(x);
    }
    public static int numberOfTrailingZeros(long i) {
        int x = (int) i;
        return x == 0 ? 32 + Integer.numberOfTrailingZeros((int) (i >>> 32)) : Integer.numberOfTrailingZeros(x);
    }
    public static long highestOneBit(long i) { return i & (MIN_VALUE >>> numberOfLeadingZeros(i)); }
    public static long lowestOneBit(long i) { return i & -i; }
    public static long rotateLeft(long i, int d) { return (i << d) | (i >>> -d); }
    public static long rotateRight(long i, int d) { return (i >>> d) | (i << -d); }
    public static long divideUnsigned(long a, long b) {
        if (b < 0) return compareUnsigned(a, b) < 0 ? 0 : 1;
        if (a >= 0) return a / b;
        long q = ((a >>> 1) / b) << 1;
        long r = a - q * b;
        return q + (compareUnsigned(r, b) >= 0 ? 1 : 0);
    }
    public static long remainderUnsigned(long a, long b) { return a - divideUnsigned(a, b) * b; }
    public static int compareUnsigned(long a, long b) { return compare(a + MIN_VALUE, b + MIN_VALUE); }
}
