package java.util.concurrent.atomic;
import java.util.function.*;
public class AtomicReference<V> {
    private volatile V value;
    public AtomicReference() { }
    public AtomicReference(V v) { value = v; }
    public final V get() { return value; }
    public final void set(V v) { value = v; }
    public final V getAndSet(V v) { V o = value; value = v; return o; }
    public final boolean compareAndSet(V e, V n) { if (value == e) { value = n; return true; } return false; }
    public final V updateAndGet(UnaryOperator<V> f) { value = f.apply(value); return value; }
    public final V getAndUpdate(UnaryOperator<V> f) { V o = value; value = f.apply(o); return o; }
    public final V accumulateAndGet(V x, BinaryOperator<V> f) { value = f.apply(value, x); return value; }
    public String toString() { return String.valueOf(value); }
}
