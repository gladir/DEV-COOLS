package java.lang;
public abstract class Enum<E extends Enum<E>> implements Comparable<E>, java.io.Serializable {
    private final String name;
    private final int ordinal;
    protected Enum(String name, int ordinal) { this.name = name; this.ordinal = ordinal; }
    public final String name() { return name; }
    public final int ordinal() { return ordinal; }
    public String toString() { return name; }
    public final boolean equals(Object other) { return this == other; }
    public final int hashCode() { return super.hashCode(); }
    protected final Object clone() throws CloneNotSupportedException { throw new CloneNotSupportedException(); }
    public final int compareTo(E o) { return ordinal - ((Enum<?>) o).ordinal; }
    public final Class<E> getDeclaringClass() {
        Class<?> c = getClass();
        Class<?> s = c.getSuperclass();
        return (s == Enum.class) ? (Class<E>) c : (Class<E>) s;
    }
    public static <T extends Enum<T>> T valueOf(Class<T> enumClass, String name) {
        if (name == null) throw new NullPointerException("Name is null");
        T[] cs = enumClass.getEnumConstants();
        for (T t : cs) if (t.name().equals(name)) return t;
        throw new IllegalArgumentException("No enum constant " + enumClass.getCanonicalName() + "." + name);
    }
}
