package java.util.concurrent.atomic;
import java.util.function.*;
public class AtomicInteger extends Number {
    private volatile int value;
    public AtomicInteger() { }
    public AtomicInteger(int v) { value = v; }
    public final int get() { return value; }
    public final void set(int v) { value = v; }
    public final void lazySet(int v) { value = v; }
    public final int getAndSet(int v) { int o = value; value = v; return o; }
    public final boolean compareAndSet(int e, int n) { if (value == e) { value = n; return true; } return false; }
    public final boolean weakCompareAndSet(int e, int n) { return compareAndSet(e, n); }
    public final int getAndIncrement() { return value++; }
    public final int getAndDecrement() { return value--; }
    public final int getAndAdd(int d) { int o = value; value += d; return o; }
    public final int incrementAndGet() { return ++value; }
    public final int decrementAndGet() { return --value; }
    public final int addAndGet(int d) { value += d; return value; }
    public final int getAndUpdate(IntUnaryOperator f) { int o = value; value = f.applyAsInt(o); return o; }
    public final int updateAndGet(IntUnaryOperator f) { value = f.applyAsInt(value); return value; }
    public final int getAndAccumulate(int x, IntBinaryOperator f) { int o = value; value = f.applyAsInt(o, x); return o; }
    public final int accumulateAndGet(int x, IntBinaryOperator f) { value = f.applyAsInt(value, x); return value; }
    public String toString() { return Integer.toString(value); }
    public int intValue() { return value; }
    public long longValue() { return value; }
    public float floatValue() { return value; }
    public double doubleValue() { return value; }
}
