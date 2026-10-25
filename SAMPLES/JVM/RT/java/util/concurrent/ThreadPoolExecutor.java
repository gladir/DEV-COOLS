package java.util.concurrent;
import java.util.*;
public class ThreadPoolExecutor implements ScheduledExecutorService {
    private static int poolSeq = 0;
    private final int poolId = ++poolSeq;
    private int threadSeq = 0;
    private final int max;
    private final LinkedList<Runnable> queue = new LinkedList<>();
    private final ArrayList<Thread> workers = new ArrayList<>();
    private int idle = 0;
    private boolean shutdown;
    private int active = 0;
    private final ThreadFactory factory;
    private int pending;
    public ThreadPoolExecutor(int core, int max, long keepAlive, TimeUnit unit, BlockingQueue<Runnable> q) { this(core, max, null); }
    public ThreadPoolExecutor(int core, int max, long keepAlive, TimeUnit unit, BlockingQueue<Runnable> q, ThreadFactory f) { this(core, max, f); }
    ThreadPoolExecutor(int core, int max, ThreadFactory f) { this.max = Math.max(1, max); this.factory = f; }
    public void execute(Runnable r) {
        if (r == null) throw new NullPointerException();
        synchronized (this) {
            if (shutdown) throw new RejectedExecutionException("Task " + r + " rejected from " + this);
            queue.add(r);
            pending++;
            if (idle == 0 && workers.size() < max) {
                final String nm = "pool-" + poolId + "-thread-" + (++threadSeq);
                Thread t;
                Runnable loop = new Runnable() { public void run() { work(); } };
                t = factory != null ? factory.newThread(loop) : new Thread(loop, nm);
                workers.add(t);
                t.start();
            } else notify();
        }
    }
    private void work() {
        while (true) {
            Runnable r;
            synchronized (this) {
                while (queue.isEmpty()) {
                    if (shutdown) { workers.remove(Thread.currentThread()); notifyAll(); return; }
                    idle++;
                    try { wait(); } catch (InterruptedException e) { idle--; workers.remove(Thread.currentThread()); notifyAll(); return; }
                    idle--;
                }
                r = queue.removeFirst();
                active++;
            }
            try { r.run(); } catch (Throwable t) { Thread th = Thread.currentThread(); System.err.print("Exception in thread \"" + th.getName() + "\" "); t.printStackTrace(); }
            synchronized (this) { active--; pending--; notifyAll(); }
        }
    }
    public synchronized void shutdown() { shutdown = true; notifyAll(); }
    public synchronized List<Runnable> shutdownNow() { shutdown = true; List<Runnable> l = new ArrayList<>(queue); queue.clear(); pending -= l.size(); notifyAll(); return l; }
    public synchronized boolean isShutdown() { return shutdown; }
    public synchronized boolean isTerminated() { return shutdown && workers.isEmpty() && queue.isEmpty(); }
    public synchronized boolean awaitTermination(long timeout, TimeUnit unit) throws InterruptedException {
        long end = System.currentTimeMillis() + unit.toMillis(timeout);
        while (!(shutdown && workers.isEmpty() && queue.isEmpty())) {
            long left = end - System.currentTimeMillis();
            if (left <= 0) return false;
            wait(Math.min(left, 100000));
        }
        return true;
    }
    public <T> Future<T> submit(Callable<T> task) { FutureTask<T> f = new FutureTask<>(task); execute(f); return f; }
    public <T> Future<T> submit(Runnable task, T result) { FutureTask<T> f = new FutureTask<>(task, result); execute(f); return f; }
    public Future<?> submit(Runnable task) { FutureTask<Object> f = new FutureTask<>(task, null); execute(f); return f; }
    public <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks) throws InterruptedException {
        List<Future<T>> l = new ArrayList<>();
        for (Callable<T> c : tasks) l.add(submit(c));
        for (Future<T> f : l) { try { f.get(); } catch (ExecutionException e) { } catch (CancellationException e) { } }
        return l;
    }
    public <T> T invokeAny(Collection<? extends Callable<T>> tasks) throws InterruptedException, ExecutionException {
        ExecutionException last = null;
        for (Callable<T> c : tasks) { try { return submit(c).get(); } catch (ExecutionException e) { last = e; } }
        throw last;
    }
    // planification
    private class Sched<V> extends FutureTask<V> implements ScheduledFuture<V> {
        long at; long period; boolean fixedRate;
        Sched(Callable<V> c, long at) { super(c); this.at = at; }
        Sched(Runnable r, long at, long period, boolean fixedRate) { super(r, null); this.at = at; this.period = period; this.fixedRate = fixedRate; this.r = r; }
        Runnable r;
        public void run() {
            if (period == 0) { super.run(); return; }
            if (isCancelled()) return;
            try { r.run(); } catch (Throwable t) { cancel(false); return; }
        }
    }
    public ScheduledFuture<?> schedule(Runnable command, long delay, TimeUnit unit) { return schedule(() -> { command.run(); return null; }, delay, unit); }
    public <V> ScheduledFuture<V> schedule(Callable<V> callable, long delay, TimeUnit unit) {
        final Sched<V> s = new Sched<>(callable, 0);
        final long ms = unit.toMillis(delay);
        execute(() -> { try { Thread.sleep(ms); } catch (InterruptedException e) { return; } s.run(); });
        return s;
    }
    public ScheduledFuture<?> scheduleAtFixedRate(Runnable command, long initialDelay, long period, TimeUnit unit) { return periodic(command, initialDelay, period, unit); }
    public ScheduledFuture<?> scheduleWithFixedDelay(Runnable command, long initialDelay, long delay, TimeUnit unit) { return periodic(command, initialDelay, delay, unit); }
    private ScheduledFuture<?> periodic(Runnable command, long initialDelay, long period, TimeUnit unit) {
        final Sched<Object> s = new Sched<>(command, 0, Math.max(1, unit.toMillis(period)), true);
        final long init = unit.toMillis(initialDelay);
        final long per = Math.max(1, unit.toMillis(period));
        execute(() -> {
            try {
                Thread.sleep(init);
                long next = System.currentTimeMillis();
                while (!s.isCancelled() && !isShutdown()) { s.run(); next += per; long w = next - System.currentTimeMillis(); if (w > 0) Thread.sleep(w); }
            } catch (InterruptedException e) { }
        });
        return s;
    }
    public int getPoolSize() { return workers.size(); }
    public int getActiveCount() { return active; }
    public long getCompletedTaskCount() { return 0; }
    public String toString() { return "java.util.concurrent.ThreadPoolExecutor@" + Integer.toHexString(hashCode()); }
}
