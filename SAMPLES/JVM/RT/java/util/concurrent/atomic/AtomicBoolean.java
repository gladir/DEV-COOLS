package java.util.concurrent.atomic;
public class AtomicBoolean {
    private volatile boolean value;
    public AtomicBoolean() { }
    public AtomicBoolean(boolean v) { value = v; }
    public final boolean get() { return value; }
    public final void set(boolean v) { value = v; }
    public final boolean getAndSet(boolean v) { boolean o = value; value = v; return o; }
    public final boolean compareAndSet(boolean e, boolean n) { if (value == e) { value = n; return true; } return false; }
    public String toString() { return Boolean.toString(value); }
}
