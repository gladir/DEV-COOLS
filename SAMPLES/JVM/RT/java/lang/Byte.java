package java.lang;
public final class Byte extends Number implements Comparable<Byte> {
    public static final byte MIN_VALUE = -128;
    public static final byte MAX_VALUE = 127;
    public static final int SIZE = 8;
    public static final int BYTES = 1;
    public static final Class<Byte> TYPE = (Class<Byte>) Class.getPrimitiveClass("byte");
    private final byte value;
    public Byte(byte value) { this.value = value; }
    public static Byte valueOf(byte b) { return new Byte(b); }
    public static Byte valueOf(String s) { return new Byte(parseByte(s)); }
    public static byte parseByte(String s) {
        int i = Integer.parseInt(s, 10);
        if (i < MIN_VALUE || i > MAX_VALUE) throw new NumberFormatException("Value out of range. Value:\"" + s + "\" Radix:10");
        return (byte) i;
    }
    public static String toString(byte b) { return Integer.toString(b); }
    public int intValue() { return value; }
    public long longValue() { return value; }
    public float floatValue() { return value; }
    public double doubleValue() { return value; }
    public byte byteValue() { return value; }
    public int hashCode() { return value; }
    public static int hashCode(byte v) { return v; }
    public boolean equals(Object o) { return o instanceof Byte && ((Byte) o).value == value; }
    public String toString() { return Integer.toString(value); }
    public int compareTo(Byte o) { return value - o.value; }
    public static int compare(byte x, byte y) { return x - y; }
    public static int toUnsignedInt(byte x) { return x & 0xff; }
}
