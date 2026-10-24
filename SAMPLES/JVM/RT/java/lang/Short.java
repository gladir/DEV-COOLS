package java.lang;
public final class Short extends Number implements Comparable<Short> {
    private static final long serialVersionUID = 7515723908773894738L;
    public static final short MIN_VALUE = -32768;
    public static final short MAX_VALUE = 32767;
    public static final int SIZE = 16;
    public static final int BYTES = 2;
    public static final Class<Short> TYPE = (Class<Short>) Class.getPrimitiveClass("short");
    private final short value;
    public Short(short value) { this.value = value; }
    public static Short valueOf(short s) { return new Short(s); }
    public static Short valueOf(String s) { return new Short(parseShort(s)); }
    public static short parseShort(String s) {
        int i = Integer.parseInt(s, 10);
        if (i < MIN_VALUE || i > MAX_VALUE) throw new NumberFormatException("Value out of range. Value:\"" + s + "\" Radix:10");
        return (short) i;
    }
    public static String toString(short s) { return Integer.toString(s); }
    public int intValue() { return value; }
    public long longValue() { return value; }
    public float floatValue() { return value; }
    public double doubleValue() { return value; }
    public short shortValue() { return value; }
    public int hashCode() { return value; }
    public static int hashCode(short v) { return v; }
    public boolean equals(Object o) { return o instanceof Short && ((Short) o).value == value; }
    public String toString() { return Integer.toString(value); }
    public int compareTo(Short o) { return value - o.value; }
    public static int compare(short x, short y) { return x - y; }
    public static int toUnsignedInt(short x) { return x & 0xffff; }
}
