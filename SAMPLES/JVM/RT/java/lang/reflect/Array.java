package java.lang.reflect;
public final class Array {
    private Array() {}
    public static Object newInstance(Class<?> componentType, int length) throws NegativeArraySizeException {
        if (componentType == void.class) throw new IllegalArgumentException();
        if (length < 0) throw new NegativeArraySizeException(String.valueOf(length));
        return java.lang.VM.newArray(componentType, length);
    }
    public static Object newInstance(Class<?> componentType, int... dimensions) {
        if (dimensions.length == 0) throw new IllegalArgumentException("Empty dimensions array");
        return multi(componentType, dimensions, 0);
    }
    private static Object multi(Class<?> ct, int[] dims, int k) {
        if (k == dims.length - 1) return newInstance(ct, dims[k]);
        Class<?> sub = ct;
        for (int i = k + 1; i < dims.length; i++) sub = newInstance(sub, 0).getClass();
        Object[] r = (Object[]) newInstance(sub, dims[k]);
        for (int i = 0; i < dims[k]; i++) r[i] = multi(ct, dims, k + 1);
        return r;
    }
    public static native int getLength(Object array);
    private static void chk(Object array, int index) {
        if (array == null) throw new NullPointerException();
        if (!array.getClass().isArray()) throw new IllegalArgumentException("Argument is not an array");
        if (index < 0 || index >= getLength(array)) throw new ArrayIndexOutOfBoundsException("Index " + index + " out of bounds for length " + getLength(array));
    }
    public static Object get(Object array, int index) {
        chk(array, index);
        if (array instanceof Object[]) return ((Object[]) array)[index];
        if (array instanceof int[]) return ((int[]) array)[index];
        if (array instanceof long[]) return ((long[]) array)[index];
        if (array instanceof double[]) return ((double[]) array)[index];
        if (array instanceof char[]) return ((char[]) array)[index];
        if (array instanceof byte[]) return ((byte[]) array)[index];
        if (array instanceof boolean[]) return ((boolean[]) array)[index];
        if (array instanceof short[]) return ((short[]) array)[index];
        return ((float[]) array)[index];
    }
    public static boolean getBoolean(Object array, int index) { chk(array, index); if (array instanceof boolean[]) return ((boolean[]) array)[index]; throw new IllegalArgumentException("Argument is not an array of primitive type"); }
    public static byte getByte(Object array, int index) { chk(array, index); if (array instanceof byte[]) return ((byte[]) array)[index]; throw new IllegalArgumentException("Argument is not an array of primitive type"); }
    public static char getChar(Object array, int index) { chk(array, index); if (array instanceof char[]) return ((char[]) array)[index]; throw new IllegalArgumentException("Argument is not an array of primitive type"); }
    public static short getShort(Object array, int index) {
        chk(array, index);
        if (array instanceof short[]) return ((short[]) array)[index];
        if (array instanceof byte[]) return ((byte[]) array)[index];
        throw new IllegalArgumentException("Argument is not an array of primitive type");
    }
    public static int getInt(Object array, int index) {
        chk(array, index);
        if (array instanceof int[]) return ((int[]) array)[index];
        if (array instanceof short[]) return ((short[]) array)[index];
        if (array instanceof byte[]) return ((byte[]) array)[index];
        if (array instanceof char[]) return ((char[]) array)[index];
        throw new IllegalArgumentException("Argument is not an array of primitive type");
    }
    public static long getLong(Object array, int index) {
        chk(array, index);
        if (array instanceof long[]) return ((long[]) array)[index];
        return getInt(array, index);
    }
    public static float getFloat(Object array, int index) {
        chk(array, index);
        if (array instanceof float[]) return ((float[]) array)[index];
        return getLong(array, index);
    }
    public static double getDouble(Object array, int index) {
        chk(array, index);
        if (array instanceof double[]) return ((double[]) array)[index];
        if (array instanceof float[]) return ((float[]) array)[index];
        return getLong(array, index);
    }
    public static void set(Object array, int index, Object value) {
        chk(array, index);
        if (array instanceof Object[]) {
            Class<?> ct = array.getClass().getComponentType();
            if (value != null && !ct.isInstance(value)) throw new IllegalArgumentException("array element type mismatch");
            ((Object[]) array)[index] = value;
            return;
        }
        if (value == null) throw new IllegalArgumentException("argument type mismatch");
        if (array instanceof int[]) setInt(array, index, num(value, 'I'));
        else if (array instanceof long[]) setLong(array, index, (long) numL(value));
        else if (array instanceof double[]) ((double[]) array)[index] = numD(value);
        else if (array instanceof float[]) ((float[]) array)[index] = (float) numD(value);
        else if (array instanceof char[]) { if (!(value instanceof Character)) throw new IllegalArgumentException("argument type mismatch"); ((char[]) array)[index] = (Character) value; }
        else if (array instanceof byte[]) { if (!(value instanceof Byte)) throw new IllegalArgumentException("argument type mismatch"); ((byte[]) array)[index] = (Byte) value; }
        else if (array instanceof boolean[]) { if (!(value instanceof Boolean)) throw new IllegalArgumentException("argument type mismatch"); ((boolean[]) array)[index] = (Boolean) value; }
        else if (array instanceof short[]) { if (!(value instanceof Short || value instanceof Byte)) throw new IllegalArgumentException("argument type mismatch"); ((short[]) array)[index] = ((Number) value).shortValue(); }
    }
    private static int num(Object v, char k) {
        if (v instanceof Integer || v instanceof Short || v instanceof Byte) return ((Number) v).intValue();
        if (v instanceof Character) return (Character) v;
        throw new IllegalArgumentException("argument type mismatch");
    }
    private static long numL(Object v) {
        if (v instanceof Long) return (Long) v;
        return num(v, 'J');
    }
    private static double numD(Object v) {
        if (v instanceof Double || v instanceof Float) return ((Number) v).doubleValue();
        return numL(v);
    }
    public static void setBoolean(Object array, int index, boolean z) { chk(array, index); if (array instanceof boolean[]) ((boolean[]) array)[index] = z; else throw new IllegalArgumentException("argument type mismatch"); }
    public static void setByte(Object array, int index, byte b) { set(array, index, Byte.valueOf(b)); }
    public static void setChar(Object array, int index, char c) { set(array, index, Character.valueOf(c)); }
    public static void setShort(Object array, int index, short s) { set(array, index, Short.valueOf(s)); }
    public static void setInt(Object array, int index, int i) { chk(array, index); if (array instanceof int[]) ((int[]) array)[index] = i; else set(array, index, Integer.valueOf(i)); }
    public static void setLong(Object array, int index, long l) { chk(array, index); if (array instanceof long[]) ((long[]) array)[index] = l; else set(array, index, Long.valueOf(l)); }
    public static void setFloat(Object array, int index, float f) { set(array, index, Float.valueOf(f)); }
    public static void setDouble(Object array, int index, double d) { set(array, index, Double.valueOf(d)); }
}
