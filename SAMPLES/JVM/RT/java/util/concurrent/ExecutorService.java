package java.util.concurrent;
import java.util.*;
public interface ExecutorService extends Executor, AutoCloseable {
    void shutdown();
    List<Runnable> shutdownNow();
    boolean isShutdown();
    boolean isTerminated();
    boolean awaitTermination(long timeout, TimeUnit unit) throws InterruptedException;
    <T> Future<T> submit(Callable<T> task);
    <T> Future<T> submit(Runnable task, T result);
    Future<?> submit(Runnable task);
    <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks) throws InterruptedException;
    <T> T invokeAny(Collection<? extends Callable<T>> tasks) throws InterruptedException, ExecutionException;
    default void close() {
        shutdown();
        try { while (!awaitTermination(1, TimeUnit.DAYS)) ; } catch (InterruptedException e) { shutdownNow(); }
    }
}
