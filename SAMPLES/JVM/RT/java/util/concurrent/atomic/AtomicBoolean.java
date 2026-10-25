package java.util.concurrent.atomic;
public class AtomicBoolean implements java.io.Serializable {
    private static final long serialVersionUID = 4654671469794556979L;
    private volatile int value;
    public AtomicBoolean() { }
    public AtomicBoolean(boolean v) { value = v ? 1 : 0; }
    public final boolean get() { return value != 0; }
    public final void set(boolean v) { value = v ? 1 : 0; }
    public final boolean getAndSet(boolean v) { boolean o = value != 0; value = v ? 1 : 0; return o; }
    public final boolean compareAndSet(boolean e, boolean n) { if ((value != 0) == e) { value = n ? 1 : 0; return true; } return false; }
    public String toString() { return Boolean.toString(value != 0); }
}
