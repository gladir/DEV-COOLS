package java.text;
public abstract class Format implements java.io.Serializable, Cloneable {
    public final String format(Object obj) { return formatObject(obj); }
    abstract String formatObject(Object o);
}
