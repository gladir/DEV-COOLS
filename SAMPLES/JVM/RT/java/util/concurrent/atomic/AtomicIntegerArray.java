package java.util.concurrent.atomic;
public class AtomicIntegerArray {
    private final int[] a;
    public AtomicIntegerArray(int n) { a = new int[n]; }
    public AtomicIntegerArray(int[] src) { a = src.clone(); }
    public final int length() { return a.length; }
    public final int get(int i) { return a[i]; }
    public final void set(int i, int v) { a[i] = v; }
    public final int incrementAndGet(int i) { return ++a[i]; }
    public final int getAndIncrement(int i) { return a[i]++; }
    public final int addAndGet(int i, int d) { a[i] += d; return a[i]; }
    public final int decrementAndGet(int i) { return --a[i]; }
    public final boolean compareAndSet(int i, int e, int n) { if (a[i] == e) { a[i] = n; return true; } return false; }
    public String toString() { return java.util.Arrays.toString(a); }
}
