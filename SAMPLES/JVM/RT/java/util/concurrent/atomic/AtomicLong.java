package java.util.concurrent.atomic;
import java.util.function.*;
public class AtomicLong extends Number {
    private volatile long value;
    public AtomicLong() { }
    public AtomicLong(long v) { value = v; }
    public final long get() { return value; }
    public final void set(long v) { value = v; }
    public final long getAndSet(long v) { long o = value; value = v; return o; }
    public final boolean compareAndSet(long e, long n) { if (value == e) { value = n; return true; } return false; }
    public final long getAndIncrement() { return value++; }
    public final long getAndDecrement() { return value--; }
    public final long getAndAdd(long d) { long o = value; value += d; return o; }
    public final long incrementAndGet() { return ++value; }
    public final long decrementAndGet() { return --value; }
    public final long addAndGet(long d) { value += d; return value; }
    public final long updateAndGet(LongUnaryOperator f) { value = f.applyAsLong(value); return value; }
    public final long getAndUpdate(LongUnaryOperator f) { long o = value; value = f.applyAsLong(o); return o; }
    public final long accumulateAndGet(long x, LongBinaryOperator f) { value = f.applyAsLong(value, x); return value; }
    public String toString() { return Long.toString(value); }
    public int intValue() { return (int) value; }
    public long longValue() { return value; }
    public float floatValue() { return value; }
    public double doubleValue() { return value; }
}
