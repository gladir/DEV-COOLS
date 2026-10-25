package java.text;
public abstract class Format implements java.io.Serializable, Cloneable {
    private static final long serialVersionUID = -299282585814624189L;
    public final String format(Object obj) { return formatObject(obj); }
    abstract String formatObject(Object o);
}
