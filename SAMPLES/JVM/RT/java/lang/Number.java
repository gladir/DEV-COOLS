package java.lang;
public abstract class Number implements java.io.Serializable {
    private static final long serialVersionUID = -8742448824652078965L;
    public Number() {}
    public abstract int intValue();
    public abstract long longValue();
    public abstract float floatValue();
    public abstract double doubleValue();
    public byte byteValue() { return (byte) intValue(); }
    public short shortValue() { return (short) intValue(); }
}
