package java.lang;
public final class Double extends Number implements Comparable<Double> {
    private static final long serialVersionUID = -9172774392245257468L;
    public static final double POSITIVE_INFINITY = 1.0 / 0.0;
    public static final double NEGATIVE_INFINITY = -1.0 / 0.0;
    public static final double NaN = 0.0d / 0.0;
    public static final double MAX_VALUE = 0x1.fffffffffffffP+1023;
    public static final double MIN_NORMAL = 0x1.0p-1022;
    public static final double MIN_VALUE = 0x0.0000000000001P-1022;
    public static final int SIZE = 64;
    public static final int BYTES = 8;
    public static final Class<Double> TYPE = (Class<Double>) Class.getPrimitiveClass("double");
    private final double value;
    public Double(double value) { this.value = value; }
    public static Double valueOf(double d) { return new Double(d); }
    public static Double valueOf(String s) { return new Double(parseDouble(s)); }
    public static native double parseDouble(String s);
    public static native String toString(double d);
    public static native long doubleToRawLongBits(double d);
    public static native double longBitsToDouble(long l);
    public static long doubleToLongBits(double d) { return isNaN(d) ? 0x7ff8000000000000L : doubleToRawLongBits(d); }
    public static boolean isNaN(double v) { return v != v; }
    public static boolean isInfinite(double v) { return v == POSITIVE_INFINITY || v == NEGATIVE_INFINITY; }
    public static boolean isFinite(double d) { return Math.abs(d) <= MAX_VALUE; }
    public boolean isNaN() { return isNaN(value); }
    public boolean isInfinite() { return isInfinite(value); }
    public int intValue() { return (int) value; }
    public long longValue() { return (long) value; }
    public float floatValue() { return (float) value; }
    public double doubleValue() { return value; }
    public int hashCode() { return hashCode(value); }
    public static int hashCode(double v) { long b = doubleToLongBits(v); return (int) (b ^ (b >>> 32)); }
    public boolean equals(Object o) { return o instanceof Double && doubleToLongBits(((Double) o).value) == doubleToLongBits(value); }
    public String toString() { return toString(value); }
    public int compareTo(Double o) { return compare(value, o.value); }
    public static int compare(double a, double b) {
        if (a < b) return -1;
        if (a > b) return 1;
        long x = doubleToLongBits(a), y = doubleToLongBits(b);
        return x == y ? 0 : (x < y ? -1 : 1);
    }
    public static double sum(double a, double b) { return a + b; }
    public static double max(double a, double b) { return Math.max(a, b); }
    public static double min(double a, double b) { return Math.min(a, b); }
}
