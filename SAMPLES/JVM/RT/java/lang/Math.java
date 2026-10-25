package java.lang;
public final class Math {
    private Math() {}
    public static final double E = 2.718281828459045;
    public static final double PI = 3.141592653589793;
    public static native double sin(double a);
    public static native double cos(double a);
    public static native double tan(double a);
    public static native double asin(double a);
    public static native double acos(double a);
    public static native double atan(double a);
    public static native double atan2(double y, double x);
    public static native double sqrt(double a);
    public static native double cbrt(double a);
    public static native double exp(double a);
    public static native double log(double a);
    public static native double log10(double a);
    public static native double pow(double a, double b);
    public static native double floor(double a);
    public static native double ceil(double a);
    public static native double rint(double a);
    public static double sinh(double x) { return (exp(x) - exp(-x)) / 2; }
    public static double cosh(double x) { return (exp(x) + exp(-x)) / 2; }
    public static double tanh(double x) { double a = exp(x), b = exp(-x); return Double.isInfinite(a) ? 1.0 : Double.isInfinite(b) ? -1.0 : (a - b) / (a + b); }
    public static double expm1(double x) { return exp(x) - 1; }
    public static double log1p(double x) { return log(1 + x); }
    public static double hypot(double x, double y) { return sqrt(x * x + y * y); }
    public static double toRadians(double d) { return d / 180.0 * PI; }
    public static double toDegrees(double r) { return r * 180.0 / PI; }
    public static double signum(double d) { return d > 0 ? 1.0 : d < 0 ? -1.0 : d; }
    public static float signum(float f) { return f > 0 ? 1.0f : f < 0 ? -1.0f : f; }
    public static int abs(int a) { return a < 0 ? -a : a; }
    public static long abs(long a) { return a < 0 ? -a : a; }
    public static float abs(float a) { return a <= 0.0F ? 0.0F - a : a; }
    public static double abs(double a) { return a <= 0.0D ? 0.0D - a : a; }
    public static int max(int a, int b) { return a >= b ? a : b; }
    public static long max(long a, long b) { return a >= b ? a : b; }
    public static float max(float a, float b) {
        if (a != a) return a;
        if (a == 0.0f && b == 0.0f && Float.floatToRawIntBits(a) == 0x80000000) return b;
        return a >= b ? a : b;
    }
    public static double max(double a, double b) {
        if (a != a) return a;
        if (a == 0.0d && b == 0.0d && Double.doubleToRawLongBits(a) == 0x8000000000000000L) return b;
        return a >= b ? a : b;
    }
    public static int min(int a, int b) { return a <= b ? a : b; }
    public static long min(long a, long b) { return a <= b ? a : b; }
    public static float min(float a, float b) {
        if (a != a) return a;
        if (a == 0.0f && b == 0.0f && Float.floatToRawIntBits(b) == 0x80000000) return b;
        return a <= b ? a : b;
    }
    public static double min(double a, double b) {
        if (a != a) return a;
        if (a == 0.0d && b == 0.0d && Double.doubleToRawLongBits(b) == 0x8000000000000000L) return b;
        return a <= b ? a : b;
    }
    public static long round(double a) {
        if (a != a) return 0;
        return (long) floor(a + 0.5d);
    }
    public static int round(float a) {
        if (a != a) return 0;
        return (int) floor(a + 0.5d);
    }
    private static java.util.Random rnd;
    public static double random() {
        if (rnd == null) rnd = new java.util.Random();
        return rnd.nextDouble();
    }
    public static int floorDiv(int x, int y) { int q = x / y; if ((x ^ y) < 0 && (q * y != x)) q--; return q; }
    public static long floorDiv(long x, long y) { long q = x / y; if ((x ^ y) < 0 && (q * y != x)) q--; return q; }
    public static long floorDiv(long x, int y) { return floorDiv(x, (long) y); }
    public static int floorMod(int x, int y) { int m = x % y; if ((m ^ y) < 0 && m != 0) m += y; return m; }
    public static long floorMod(long x, long y) { long m = x % y; if ((m ^ y) < 0 && m != 0) m += y; return m; }
    public static int floorMod(long x, int y) { return (int) floorMod(x, (long) y); }
    public static int ceilDiv(int x, int y) { return -floorDiv(-x, y); }
    public static int addExact(int x, int y) { int r = x + y; if (((x ^ r) & (y ^ r)) < 0) throw new ArithmeticException("integer overflow"); return r; }
    public static long addExact(long x, long y) { long r = x + y; if (((x ^ r) & (y ^ r)) < 0) throw new ArithmeticException("long overflow"); return r; }
    public static int subtractExact(int x, int y) { int r = x - y; if (((x ^ y) & (x ^ r)) < 0) throw new ArithmeticException("integer overflow"); return r; }
    public static long subtractExact(long x, long y) { long r = x - y; if (((x ^ y) & (x ^ r)) < 0) throw new ArithmeticException("long overflow"); return r; }
    public static int multiplyExact(int x, int y) { long r = (long) x * (long) y; if ((int) r != r) throw new ArithmeticException("integer overflow"); return (int) r; }
    public static long multiplyExact(long x, long y) {
        long r = x * y;
        long ax = abs(x), ay = abs(y);
        if (((ax | ay) >>> 31 != 0)) {
            if (((y != 0) && (r / y != x)) || (x == Long.MIN_VALUE && y == -1)) throw new ArithmeticException("long overflow");
        }
        return r;
    }
    public static int negateExact(int a) { if (a == Integer.MIN_VALUE) throw new ArithmeticException("integer overflow"); return -a; }
    public static long negateExact(long a) { if (a == Long.MIN_VALUE) throw new ArithmeticException("long overflow"); return -a; }
    public static int incrementExact(int a) { if (a == Integer.MAX_VALUE) throw new ArithmeticException("integer overflow"); return a + 1; }
    public static int decrementExact(int a) { if (a == Integer.MIN_VALUE) throw new ArithmeticException("integer overflow"); return a - 1; }
    public static int toIntExact(long value) { if ((int) value != value) throw new ArithmeticException("integer overflow"); return (int) value; }
    public static int absExact(int a) { if (a == Integer.MIN_VALUE) throw new ArithmeticException("Overflow to represent absolute value of Integer.MIN_VALUE"); return abs(a); }
    public static int clamp(long value, int min, int max) { return (int) Math.min(max, Math.max(value, min)); }
    public static double clamp(double value, double min, double max) { return Math.min(max, Math.max(value, min)); }
    public static double fma(double a, double b, double c) { return a * b + c; }
    public static double ulp(double d) { return Math.abs(Double.longBitsToDouble(Double.doubleToRawLongBits(d) + 1) - d); }
    public static double copySign(double m, double s) { return (s < 0 || (s == 0 && 1 / s < 0)) ? -abs(m) : abs(m); }
    public static int getExponent(double d) { return (int) (((Double.doubleToRawLongBits(d) & 0x7FF0000000000000L) >> 52) - 1023); }
}
