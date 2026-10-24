package java.util.concurrent.atomic;
public class AtomicIntegerArray implements java.io.Serializable {
    private static final long serialVersionUID = 2862133569453604235L;
    private final int[] array;
    public AtomicIntegerArray(int n) { array = new int[n]; }
    public AtomicIntegerArray(int[] src) { array = src.clone(); }
    public final int length() { return array.length; }
    public final int get(int i) { return array[i]; }
    public final void set(int i, int v) { array[i] = v; }
    public final int incrementAndGet(int i) { return ++array[i]; }
    public final int getAndIncrement(int i) { return array[i]++; }
    public final int addAndGet(int i, int d) { array[i] += d; return array[i]; }
    public final int decrementAndGet(int i) { return --array[i]; }
    public final boolean compareAndSet(int i, int e, int n) { if (array[i] == e) { array[i] = n; return true; } return false; }
    public String toString() { return java.util.Arrays.toString(array); }
}
