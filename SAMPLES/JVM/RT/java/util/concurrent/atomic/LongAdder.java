package java.util.concurrent.atomic;
public class LongAdder extends Number {
    private long v;
    public void add(long x) { v += x; }
    public void increment() { v++; }
    public void decrement() { v--; }
    public long sum() { return v; }
    public void reset() { v = 0; }
    public long sumThenReset() { long r = v; v = 0; return r; }
    public String toString() { return Long.toString(v); }
    public int intValue() { return (int) v; }
    public long longValue() { return v; }
    public float floatValue() { return v; }
    public double doubleValue() { return v; }
}
