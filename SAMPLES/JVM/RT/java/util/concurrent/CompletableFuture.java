package java.util.concurrent;
import java.util.*;
import java.util.function.*;
public class CompletableFuture<T> implements Future<T>, CompletionStage<T> {
    private T value;
    private Throwable ex;
    private boolean done;
    private final ArrayList<Runnable> callbacks = new ArrayList<>();
    public CompletableFuture() { }
    private static final Executor ASYNC = r -> { Thread t = new Thread(r, "ForkJoinPool.commonPool-worker-" + (++seq)); t.setDaemon(true); t.start(); };
    private static int seq = 0;
    public static <U> CompletableFuture<U> supplyAsync(Supplier<U> s) { return supplyAsync(s, ASYNC); }
    public static <U> CompletableFuture<U> supplyAsync(Supplier<U> s, Executor e) {
        CompletableFuture<U> f = new CompletableFuture<>();
        e.execute(() -> { try { f.complete(s.get()); } catch (Throwable t) { f.completeExceptionally(t instanceof CompletionException ? t : new CompletionException(t)); } });
        return f;
    }
    public static CompletableFuture<Void> runAsync(Runnable r) { return runAsync(r, ASYNC); }
    public static CompletableFuture<Void> runAsync(Runnable r, Executor e) { return supplyAsync(() -> { r.run(); return null; }, e); }
    public static <U> CompletableFuture<U> completedFuture(U v) { CompletableFuture<U> f = new CompletableFuture<>(); f.complete(v); return f; }
    public static <U> CompletableFuture<U> failedFuture(Throwable t) { CompletableFuture<U> f = new CompletableFuture<>(); f.completeExceptionally(t); return f; }
    public boolean complete(T v) {
        ArrayList<Runnable> cbs;
        synchronized (this) { if (done) return false; value = v; done = true; notifyAll(); cbs = new ArrayList<>(callbacks); callbacks.clear(); }
        for (Runnable r : cbs) r.run();
        return true;
    }
    public boolean completeExceptionally(Throwable t) {
        ArrayList<Runnable> cbs;
        synchronized (this) { if (done) return false; ex = t; done = true; notifyAll(); cbs = new ArrayList<>(callbacks); callbacks.clear(); }
        for (Runnable r : cbs) r.run();
        return true;
    }
    private void onDone(Runnable r) {
        boolean now;
        synchronized (this) { now = done; if (!now) callbacks.add(r); }
        if (now) r.run();
    }
    public synchronized boolean isDone() { return done; }
    public synchronized boolean isCompletedExceptionally() { return done && ex != null; }
    public boolean cancel(boolean b) { return completeExceptionally(new CancellationException()); }
    public synchronized boolean isCancelled() { return done && ex instanceof CancellationException; }
    private Throwable unwrap(Throwable t) { return (t instanceof CompletionException && t.getCause() != null) ? t.getCause() : t; }
    public synchronized T get() throws InterruptedException, ExecutionException {
        while (!done) wait();
        if (ex != null) { if (ex instanceof CancellationException) throw (CancellationException) ex; throw new ExecutionException(unwrap(ex)); }
        return value;
    }
    public synchronized T get(long timeout, TimeUnit unit) throws InterruptedException, ExecutionException, TimeoutException {
        long end = System.currentTimeMillis() + unit.toMillis(timeout);
        while (!done) { long left = end - System.currentTimeMillis(); if (left <= 0) throw new TimeoutException(); wait(left); }
        if (ex != null) throw new ExecutionException(unwrap(ex));
        return value;
    }
    public synchronized T join() {
        while (!done) { try { wait(); } catch (InterruptedException e) { } }
        if (ex != null) { if (ex instanceof CancellationException) throw (CancellationException) ex; throw (ex instanceof CompletionException) ? (CompletionException) ex : new CompletionException(ex); }
        return value;
    }
    public synchronized T getNow(T d) { if (!done) return d; return join(); }
    private <U> CompletableFuture<U> chain(BiConsumer<CompletableFuture<U>, CompletableFuture<T>> body) {
        CompletableFuture<U> f = new CompletableFuture<>();
        onDone(() -> body.accept(f, this));
        return f;
    }
    private static Throwable wrap(Throwable t) { return t instanceof CompletionException ? t : new CompletionException(t); }
    public <U> CompletableFuture<U> thenApply(Function<? super T, ? extends U> fn) {
        return chain((f, src) -> { if (src.ex != null) f.completeExceptionally(wrap(src.ex)); else { try { f.complete(fn.apply(src.value)); } catch (Throwable t) { f.completeExceptionally(wrap(t)); } } });
    }
    public <U> CompletableFuture<U> thenApplyAsync(Function<? super T, ? extends U> fn) { return thenApply(fn); }
    public CompletableFuture<Void> thenAccept(Consumer<? super T> c) {
        return chain((f, src) -> { if (src.ex != null) f.completeExceptionally(wrap(src.ex)); else { try { c.accept(src.value); f.complete(null); } catch (Throwable t) { f.completeExceptionally(wrap(t)); } } });
    }
    public CompletableFuture<Void> thenAcceptAsync(Consumer<? super T> c) { return thenAccept(c); }
    public CompletableFuture<Void> thenRun(Runnable r) {
        return chain((f, src) -> { if (src.ex != null) f.completeExceptionally(wrap(src.ex)); else { try { r.run(); f.complete(null); } catch (Throwable t) { f.completeExceptionally(wrap(t)); } } });
    }
    public <U> CompletableFuture<U> thenCompose(Function<? super T, ? extends CompletionStage<U>> fn) {
        return chain((f, src) -> {
            if (src.ex != null) f.completeExceptionally(wrap(src.ex));
            else { try { CompletableFuture<U> n = (CompletableFuture<U>) fn.apply(src.value); n.onDone(() -> { if (n.ex != null) f.completeExceptionally(wrap(n.ex)); else f.complete(n.value); }); } catch (Throwable t) { f.completeExceptionally(wrap(t)); } }
        });
    }
    public <U, V> CompletableFuture<V> thenCombine(CompletionStage<? extends U> other, BiFunction<? super T, ? super U, ? extends V> fn) {
        CompletableFuture<U> o = (CompletableFuture<U>) other;
        CompletableFuture<V> f = new CompletableFuture<>();
        onDone(() -> o.onDone(() -> {
            if (ex != null) f.completeExceptionally(wrap(ex)); else if (o.ex != null) f.completeExceptionally(wrap(o.ex));
            else { try { f.complete(fn.apply(value, o.value)); } catch (Throwable t) { f.completeExceptionally(wrap(t)); } }
        }));
        return f;
    }
    public <U> CompletableFuture<Void> thenAcceptBoth(CompletionStage<? extends U> other, BiConsumer<? super T, ? super U> c) {
        return thenCombine(other, (a, b) -> { c.accept(a, b); return null; });
    }
    public CompletableFuture<T> exceptionally(Function<Throwable, ? extends T> fn) {
        return chain((f, src) -> { if (src.ex == null) f.complete(src.value); else { try { f.complete(fn.apply(src.ex)); } catch (Throwable t) { f.completeExceptionally(wrap(t)); } } });
    }
    public <U> CompletableFuture<U> handle(BiFunction<? super T, Throwable, ? extends U> fn) {
        return chain((f, src) -> { try { f.complete(fn.apply(src.ex == null ? src.value : null, src.ex)); } catch (Throwable t) { f.completeExceptionally(wrap(t)); } });
    }
    public CompletableFuture<T> whenComplete(BiConsumer<? super T, ? super Throwable> c) {
        return chain((f, src) -> { try { c.accept(src.ex == null ? src.value : null, src.ex); } catch (Throwable t) { if (src.ex == null) { f.completeExceptionally(wrap(t)); return; } } if (src.ex != null) f.completeExceptionally(wrap(src.ex)); else f.complete(src.value); });
    }
    public CompletableFuture<T> orTimeout(long t, TimeUnit u) { return this; }
    public CompletableFuture<T> toCompletableFuture() { return this; }
    public static CompletableFuture<Void> allOf(CompletableFuture<?>... cfs) {
        CompletableFuture<Void> f = new CompletableFuture<>();
        if (cfs.length == 0) { f.complete(null); return f; }
        final int[] left = { cfs.length };
        for (CompletableFuture<?> c : cfs) c.onDone(() -> {
            boolean last;
            synchronized (left) { last = --left[0] == 0; }
            if (last) { Throwable t = null; for (CompletableFuture<?> x : cfs) if (x.ex != null) { t = x.ex; break; } if (t != null) f.completeExceptionally(wrap(t)); else f.complete(null); }
        });
        return f;
    }
    public static CompletableFuture<Object> anyOf(CompletableFuture<?>... cfs) {
        CompletableFuture<Object> f = new CompletableFuture<>();
        for (CompletableFuture<?> c : cfs) c.onDone(() -> { if (c.ex != null) f.completeExceptionally(wrap(c.ex)); else f.complete(c.value); });
        return f;
    }
    public String toString() { return "CompletableFuture@" + Integer.toHexString(hashCode()) + (done ? (ex != null ? "[Completed exceptionally: " + ex + "]" : "[Completed normally]") : "[Not completed]"); }
}
