package java.lang;
public final class Boolean implements java.io.Serializable, Comparable<Boolean> {
    public static final Boolean TRUE = new Boolean(true);
    public static final Boolean FALSE = new Boolean(false);
    public static final Class<Boolean> TYPE = (Class<Boolean>) Class.getPrimitiveClass("boolean");
    private final boolean value;
    public Boolean(boolean value) { this.value = value; }
    public static Boolean valueOf(boolean b) { return b ? TRUE : FALSE; }
    public static Boolean valueOf(String s) { return parseBoolean(s) ? TRUE : FALSE; }
    public static boolean parseBoolean(String s) { return s != null && s.equalsIgnoreCase("true"); }
    public boolean booleanValue() { return value; }
    public static String toString(boolean b) { return b ? "true" : "false"; }
    public String toString() { return value ? "true" : "false"; }
    public int hashCode() { return value ? 1231 : 1237; }
    public static int hashCode(boolean v) { return v ? 1231 : 1237; }
    public boolean equals(Object o) { return o instanceof Boolean && ((Boolean) o).value == value; }
    public int compareTo(Boolean o) { return compare(value, o.value); }
    public static int compare(boolean x, boolean y) { return x == y ? 0 : (x ? 1 : -1); }
    public static boolean logicalAnd(boolean a, boolean b) { return a && b; }
    public static boolean logicalOr(boolean a, boolean b) { return a || b; }
    public static boolean logicalXor(boolean a, boolean b) { return a ^ b; }
}
