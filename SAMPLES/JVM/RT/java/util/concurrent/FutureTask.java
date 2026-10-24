package java.util.concurrent;
public class FutureTask<V> implements RunnableFuture<V> {
    private Callable<V> callable;
    private V result;
    private Throwable exception;
    private boolean done, cancelled;
    public FutureTask(Callable<V> callable) { if (callable == null) throw new NullPointerException(); this.callable = callable; }
    public FutureTask(Runnable runnable, V result) { this.callable = () -> { runnable.run(); return result; }; }
    public synchronized boolean isCancelled() { return cancelled; }
    public synchronized boolean isDone() { return done; }
    public synchronized boolean cancel(boolean mayInterrupt) { if (done) return false; cancelled = true; done = true; notifyAll(); return true; }
    public void run() {
        synchronized (this) { if (done) return; }
        V r = null; Throwable ex = null;
        try { r = callable.call(); } catch (Throwable t) { ex = t; }
        synchronized (this) { if (!done) { result = r; exception = ex; done = true; } notifyAll(); }
        done();
    }
    protected void done() { }
    public synchronized V get() throws InterruptedException, ExecutionException {
        while (!done) wait();
        if (cancelled) throw new CancellationException();
        if (exception != null) throw new ExecutionException(exception);
        return result;
    }
    public synchronized V get(long timeout, TimeUnit unit) throws InterruptedException, ExecutionException, TimeoutException {
        long end = System.currentTimeMillis() + unit.toMillis(timeout);
        while (!done) {
            long left = end - System.currentTimeMillis();
            if (left <= 0) throw new TimeoutException();
            wait(left);
        }
        if (cancelled) throw new CancellationException();
        if (exception != null) throw new ExecutionException(exception);
        return result;
    }
}
