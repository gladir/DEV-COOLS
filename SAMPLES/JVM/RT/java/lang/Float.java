package java.lang;
public final class Float extends Number implements Comparable<Float> {
    public static final float POSITIVE_INFINITY = 1.0f / 0.0f;
    public static final float NEGATIVE_INFINITY = -1.0f / 0.0f;
    public static final float NaN = 0.0f / 0.0f;
    public static final float MAX_VALUE = 0x1.fffffeP+127f;
    public static final float MIN_NORMAL = 0x1.0p-126f;
    public static final float MIN_VALUE = 0x0.000002P-126f;
    public static final int SIZE = 32;
    public static final int BYTES = 4;
    public static final Class<Float> TYPE = (Class<Float>) Class.getPrimitiveClass("float");
    private final float value;
    public Float(float value) { this.value = value; }
    public Float(double value) { this.value = (float) value; }
    public static Float valueOf(float f) { return new Float(f); }
    public static Float valueOf(String s) { return new Float(parseFloat(s)); }
    public static float parseFloat(String s) { return (float) Double.parseDouble(s); }
    public static native String toString(float f);
    public static native int floatToRawIntBits(float f);
    public static native float intBitsToFloat(int i);
    public static int floatToIntBits(float f) { return isNaN(f) ? 0x7fc00000 : floatToRawIntBits(f); }
    public static boolean isNaN(float v) { return v != v; }
    public static boolean isInfinite(float v) { return v == POSITIVE_INFINITY || v == NEGATIVE_INFINITY; }
    public static boolean isFinite(float f) { return Math.abs(f) <= MAX_VALUE; }
    public boolean isNaN() { return isNaN(value); }
    public boolean isInfinite() { return isInfinite(value); }
    public int intValue() { return (int) value; }
    public long longValue() { return (long) value; }
    public float floatValue() { return value; }
    public double doubleValue() { return value; }
    public int hashCode() { return floatToIntBits(value); }
    public static int hashCode(float v) { return floatToIntBits(v); }
    public boolean equals(Object o) { return o instanceof Float && floatToIntBits(((Float) o).value) == floatToIntBits(value); }
    public String toString() { return toString(value); }
    public int compareTo(Float o) { return compare(value, o.value); }
    public static int compare(float a, float b) {
        if (a < b) return -1;
        if (a > b) return 1;
        int x = floatToIntBits(a), y = floatToIntBits(b);
        return x == y ? 0 : (x < y ? -1 : 1);
    }
    public static float sum(float a, float b) { return a + b; }
    public static float max(float a, float b) { return Math.max(a, b); }
    public static float min(float a, float b) { return Math.min(a, b); }
}
