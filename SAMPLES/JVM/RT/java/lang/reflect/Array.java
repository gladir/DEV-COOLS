package java.lang.reflect;
public final class Array {
    private Array() {}
    public static Object newInstance(Class<?> componentType, int length) {
        if (length < 0) throw new NegativeArraySizeException(String.valueOf(length));
        return java.lang.VM.newArray(componentType, length);
    }
    public static native int getLength(Object array);
    public static Object get(Object array, int index) {
        if (array instanceof Object[]) return ((Object[]) array)[index];
        if (array instanceof int[]) return ((int[]) array)[index];
        if (array instanceof long[]) return ((long[]) array)[index];
        if (array instanceof double[]) return ((double[]) array)[index];
        if (array instanceof char[]) return ((char[]) array)[index];
        if (array instanceof byte[]) return ((byte[]) array)[index];
        if (array instanceof boolean[]) return ((boolean[]) array)[index];
        if (array instanceof short[]) return ((short[]) array)[index];
        if (array instanceof float[]) return ((float[]) array)[index];
        throw new IllegalArgumentException("Argument is not an array");
    }
    public static void set(Object array, int index, Object value) {
        if (array instanceof Object[]) ((Object[]) array)[index] = value;
        else if (array instanceof int[]) ((int[]) array)[index] = (Integer) value;
        else if (array instanceof long[]) ((long[]) array)[index] = (Long) value;
        else if (array instanceof double[]) ((double[]) array)[index] = (Double) value;
        else if (array instanceof char[]) ((char[]) array)[index] = (Character) value;
        else if (array instanceof byte[]) ((byte[]) array)[index] = (Byte) value;
        else if (array instanceof boolean[]) ((boolean[]) array)[index] = (Boolean) value;
        else throw new IllegalArgumentException("Argument is not an array");
    }
}
