package java.lang;
public final class Integer extends Number implements Comparable<Integer> {
    private static final long serialVersionUID = 1360826667806852920L;
    public static final int MIN_VALUE = 0x80000000;
    public static final int MAX_VALUE = 0x7fffffff;
    public static final int SIZE = 32;
    public static final int BYTES = 4;
    public static final Class<Integer> TYPE = (Class<Integer>) Class.getPrimitiveClass("int");
    private final int value;
    private static final Integer[] cache = new Integer[256];
    public Integer(int value) { this.value = value; }
    public Integer(String s) { this.value = parseInt(s, 10); }
    public static Integer valueOf(int i) {
        if (i >= -128 && i <= 127) {
            Integer r = cache[i + 128];
            if (r == null) { r = new Integer(i); cache[i + 128] = r; }
            return r;
        }
        return new Integer(i);
    }
    public static Integer valueOf(String s) { return valueOf(parseInt(s, 10)); }
    public static Integer valueOf(String s, int radix) { return valueOf(parseInt(s, radix)); }
    public static int parseInt(String s) { return parseInt(s, 10); }
    public static int parseInt(String s, int radix) {
        if (s == null) throw new NumberFormatException("Cannot parse null string: null");
        int len = s.length();
        if (len == 0) throw new NumberFormatException("For input string: \"\"" + (radix != 10 ? " under radix " + radix : ""));
        int i = 0;
        boolean neg = false;
        char first = s.charAt(0);
        if (first == '-' || first == '+') {
            neg = first == '-';
            i = 1;
            if (len == 1) throw new NumberFormatException("For input string: \"" + s + "\"" + (radix != 10 ? " under radix " + radix : ""));
        }
        long r = 0;
        while (i < len) {
            int d = Character.digit(s.charAt(i++), radix);
            if (d < 0) throw new NumberFormatException("For input string: \"" + s + "\"" + (radix != 10 ? " under radix " + radix : ""));
            r = r * radix + d;
            if (r > 2147483648L) throw new NumberFormatException("For input string: \"" + s + "\"" + (radix != 10 ? " under radix " + radix : ""));
        }
        if (neg) r = -r;
        if (r > 2147483647L || r < -2147483648L) throw new NumberFormatException("For input string: \"" + s + "\"" + (radix != 10 ? " under radix " + radix : ""));
        return (int) r;
    }
    public static int parseUnsignedInt(String s) { return (int) Long.parseLong(s); }
    public static Integer decode(String nm) {
        int radix = 10, index = 0;
        boolean neg = false;
        if (nm.isEmpty()) throw new NumberFormatException("Zero length string");
        char c = nm.charAt(0);
        if (c == '-') { neg = true; index++; } else if (c == '+') index++;
        if (nm.startsWith("0x", index) || nm.startsWith("0X", index)) { index += 2; radix = 16; }
        else if (nm.startsWith("#", index)) { index++; radix = 16; }
        else if (nm.startsWith("0", index) && nm.length() > 1 + index) { index++; radix = 8; }
        int r = parseInt(nm.substring(index), radix);
        return valueOf(neg ? -r : r);
    }
    public static native String toString(int i);
    public static String toString(int i, int radix) {
        if (radix < 2 || radix > 36) radix = 10;
        if (radix == 10) return toString(i);
        if (i == 0) return "0";
        char[] buf = new char[33];
        int pos = 33;
        boolean neg = i < 0;
        long v = i;
        if (neg) v = -v;
        while (v > 0) { buf[--pos] = Character.forDigit((int) (v % radix), radix); v /= radix; }
        if (neg) buf[--pos] = '-';
        return new String(buf, pos, 33 - pos);
    }
    public static native String toHexString(int i);
    public static String toBinaryString(int i) { return toUnsignedString(i, 1); }
    public static String toOctalString(int i) { return toUnsignedString(i, 3); }
    private static String toUnsignedString(int i, int shift) {
        if (i == 0) return "0";
        char[] buf = new char[32];
        int pos = 32;
        int mask = (1 << shift) - 1;
        while (i != 0) { buf[--pos] = Character.forDigit(i & mask, 1 << shift); i >>>= shift; }
        return new String(buf, pos, 32 - pos);
    }
    public static String toUnsignedString(int i) { return Long.toString(i & 0xffffffffL); }
    public static long toUnsignedLong(int x) { return x & 0xffffffffL; }
    public static int divideUnsigned(int a, int b) { return (int) ((a & 0xffffffffL) / (b & 0xffffffffL)); }
    public static int remainderUnsigned(int a, int b) { return (int) ((a & 0xffffffffL) % (b & 0xffffffffL)); }
    public static int compareUnsigned(int a, int b) { return compare(a + MIN_VALUE, b + MIN_VALUE); }
    public int intValue() { return value; }
    public long longValue() { return value; }
    public float floatValue() { return value; }
    public double doubleValue() { return value; }
    public byte byteValue() { return (byte) value; }
    public short shortValue() { return (short) value; }
    public int hashCode() { return value; }
    public static int hashCode(int v) { return v; }
    public boolean equals(Object o) { return o instanceof Integer && ((Integer) o).value == value; }
    public String toString() { return toString(value); }
    public int compareTo(Integer o) { return compare(value, o.value); }
    public static int compare(int x, int y) { return x < y ? -1 : (x == y ? 0 : 1); }
    public static int signum(int i) { return (i >> 31) | (-i >>> 31); }
    public static int sum(int a, int b) { return a + b; }
    public static int max(int a, int b) { return a >= b ? a : b; }
    public static int min(int a, int b) { return a <= b ? a : b; }
    public static int bitCount(int i) {
        i = i - ((i >>> 1) & 0x55555555);
        i = (i & 0x33333333) + ((i >>> 2) & 0x33333333);
        i = (i + (i >>> 4)) & 0x0f0f0f0f;
        i = i + (i >>> 8);
        i = i + (i >>> 16);
        return i & 0x3f;
    }
    public static int numberOfLeadingZeros(int i) {
        if (i <= 0) return i == 0 ? 32 : 0;
        int n = 31;
        if (i >= 1 << 16) { n -= 16; i >>>= 16; }
        if (i >= 1 << 8) { n -= 8; i >>>= 8; }
        if (i >= 1 << 4) { n -= 4; i >>>= 4; }
        if (i >= 1 << 2) { n -= 2; i >>>= 2; }
        return n - (i >>> 1);
    }
    public static int numberOfTrailingZeros(int i) {
        if (i == 0) return 32;
        int n = 0;
        while ((i & 1) == 0) { n++; i >>>= 1; }
        return n;
    }
    public static int highestOneBit(int i) { return i & (MIN_VALUE >>> numberOfLeadingZeros(i)); }
    public static int lowestOneBit(int i) { return i & -i; }
    public static int reverse(int i) {
        int r = 0;
        for (int k = 0; k < 32; k++) { r = (r << 1) | (i & 1); i >>>= 1; }
        return r;
    }
    public static int reverseBytes(int i) { return (i << 24) | ((i & 0xff00) << 8) | ((i >>> 8) & 0xff00) | (i >>> 24); }
    public static int rotateLeft(int i, int d) { return (i << d) | (i >>> -d); }
    public static int rotateRight(int i, int d) { return (i >>> d) | (i << -d); }
    public static Integer getInteger(String nm) { return null; }
}
