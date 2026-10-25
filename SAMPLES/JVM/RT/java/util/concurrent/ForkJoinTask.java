package java.util.concurrent;
public abstract class ForkJoinTask<V> implements Future<V> {
    private static final long serialVersionUID = -7721805057305804111L;
    private boolean done;
    private V result;
    protected abstract boolean exec0();
    abstract V result0();
    public final ForkJoinTask<V> fork() { invoke(); return this; }
    public final V join() { invoke(); return getRawResult(); }
    public final V invoke() { if (!done) { exec0(); done = true; } return getRawResult(); }
    public abstract V getRawResult();
    public boolean cancel(boolean b) { return false; }
    public boolean isCancelled() { return false; }
    public boolean isDone() { return done; }
    public V get() { return invoke(); }
    public V get(long t, TimeUnit u) { return invoke(); }
    public static void invokeAll(ForkJoinTask<?> a, ForkJoinTask<?> b) { a.invoke(); b.invoke(); }
}
