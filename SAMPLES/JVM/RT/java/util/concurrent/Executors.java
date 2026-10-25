package java.util.concurrent;
public class Executors {
    private Executors() {}
    public static ExecutorService newFixedThreadPool(int n) { return new ThreadPoolExecutor(n, n, null); }
    public static ExecutorService newFixedThreadPool(int n, ThreadFactory f) { return new ThreadPoolExecutor(n, n, f); }
    public static ExecutorService newCachedThreadPool() { return new ThreadPoolExecutor(0, 100000, null); }
    public static ExecutorService newSingleThreadExecutor() { return new ThreadPoolExecutor(1, 1, null); }
    public static ExecutorService newWorkStealingPool() { return new ThreadPoolExecutor(4, 4, null); }
    public static ExecutorService newWorkStealingPool(int n) { return new ThreadPoolExecutor(n, n, null); }
    public static ExecutorService newVirtualThreadPerTaskExecutor() { return new ThreadPoolExecutor(0, 100000, null); }
    public static ScheduledExecutorService newScheduledThreadPool(int n) { return new ScheduledThreadPoolExecutor(n); }
    public static ScheduledExecutorService newSingleThreadScheduledExecutor() { return new ScheduledThreadPoolExecutor(1); }
    public static ThreadFactory defaultThreadFactory() { return r -> new Thread(r); }
    public static <T> Callable<T> callable(Runnable task, T result) { return () -> { task.run(); return result; }; }
}
