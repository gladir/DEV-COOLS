package java.lang;
public class Thread implements Runnable {
    private static Thread mainThread;
    private static UncaughtExceptionHandler defaultHandler;
    private Runnable target;
    private String name;
    private boolean started, daemon;
    private int priority = 5;
    private long id;
    private UncaughtExceptionHandler handler;
    public static final int MIN_PRIORITY = 1, NORM_PRIORITY = 5, MAX_PRIORITY = 10;
    public Thread() { this((Runnable) null, (String) null); }
    public Thread(Runnable target) { this(target, (String) null); }
    public Thread(String name) { this((Runnable) null, name); }
    public Thread(ThreadGroup g, Runnable target) { this(target, (String) null); }
    public Thread(ThreadGroup g, Runnable target, String name) { this(target, name); }
    public Thread(Runnable target, String name) {
        this.target = target;
        this.id = ++idSeq;
        this.name = name != null ? name : "Thread-" + (numberSeq++);
    }
    private static long idSeq = 1;
    private static int numberSeq = 0;
    static native Thread current0();
    static native void setCurrent0(Thread t);
    private native void start0(boolean daemon);
    private static native void sleep0(long ms);
    private static native void yield0();
    private native void join0(long ms);
    private native boolean isAlive0();
    private native void interrupt0();
    private native boolean isInterrupted0(boolean clear);
    public static native boolean holdsLock(Object o);
    public static Thread currentThread() {
        Thread t = current0();
        if (t == null) {
            t = new Thread((Runnable) null, "main");
            t.id = 1; t.started = true;
            idSeq--;
            setCurrent0(t);
        }
        return t;
    }
    public void run() { if (target != null) target.run(); }
    public void start() {
        if (started) throw new IllegalThreadStateException();
        started = true;
        start0(daemon);
    }
    static void runThread(Thread t) {
        try { t.run(); }
        catch (Throwable e) {
            UncaughtExceptionHandler h = t.handler != null ? t.handler : defaultHandler;
            if (h != null) { try { h.uncaughtException(t, e); } catch (Throwable x) { } }
            else {
                System.err.print("Exception in thread \"" + t.name + "\" ");
                e.printStackTrace();
            }
        }
    }
    public final void join() throws InterruptedException { join0(0); }
    public final void join(long ms) throws InterruptedException { join0(ms <= 0 ? 0 : ms); }
    public static void sleep(long ms) throws InterruptedException {
        if (ms < 0) throw new IllegalArgumentException("timeout value is negative");
        if (VM.pumpHook != null && currentThread() == mainThread()) {
            long end = System.currentTimeMillis() + ms;
            do { VM.pumpHook.run(); long left = end - System.currentTimeMillis(); if (left > 0) sleep0(Math.min(left, 8)); } while (System.currentTimeMillis() < end);
        } else sleep0(ms);
    }
    private static Thread mainThread() { if (mainThread == null) { Thread t = current0(); mainThread = t; } return mainThread; }
    public static void sleep(long ms, int nanos) throws InterruptedException { sleep(ms); }
    public static void sleep(java.time.Duration d) throws InterruptedException { sleep(d.toMillis()); }
    public static void yield() { yield0(); }
    public static void onSpinWait() { yield0(); }
    public void interrupt() { interrupt0(); }
    public boolean isInterrupted() { return isInterrupted0(false); }
    public static boolean interrupted() { return currentThread().isInterrupted0(true); }
    public final boolean isAlive() { return started && (id == 1 || isAlive0()); }
    public final boolean isDaemon() { return daemon; }
    public final void setDaemon(boolean on) { if (started) throw new IllegalThreadStateException(); daemon = on; }
    public final String getName() { return name; }
    public final void setName(String n) { name = n; }
    public long getId() { return id; }
    public long threadId() { return id; }
    public final int getPriority() { return priority; }
    public final void setPriority(int p) { if (p < 1 || p > 10) throw new IllegalArgumentException(); priority = p; }
    public StackTraceElement[] getStackTrace() { return new StackTraceElement[0]; }
    public boolean isVirtual() { return false; }
    public ThreadGroup getThreadGroup() { return new ThreadGroup("main"); }
    public String toString() { return "Thread[#" + id + "," + name + "," + priority + ",main]"; }
    public static Thread startVirtualThread(Runnable r) { Thread t = new Thread(r); t.setDaemon(true); t.start(); return t; }
    public static Builder ofVirtual() { return new Builder(); }
    public static Builder ofPlatform() { return new Builder(); }
    public static class Builder {
        private String nm;
        public Builder name(String n) { nm = n; return this; }
        public Builder name(String n, long start) { nm = n + start; return this; }
        public Thread start(Runnable r) { Thread t = unstarted(r); t.start(); return t; }
        public Thread unstarted(Runnable r) { return nm == null ? new Thread(r) : new Thread(r, nm); }
    }
    public enum State { NEW, RUNNABLE, BLOCKED, WAITING, TIMED_WAITING, TERMINATED }
    public State getState() { return !started ? State.NEW : ((id == 1 || isAlive0()) ? State.RUNNABLE : State.TERMINATED); }
    public interface UncaughtExceptionHandler { void uncaughtException(Thread t, Throwable e); }
    public void setUncaughtExceptionHandler(UncaughtExceptionHandler h) { handler = h; }
    public UncaughtExceptionHandler getUncaughtExceptionHandler() { return handler; }
    public static void setDefaultUncaughtExceptionHandler(UncaughtExceptionHandler h) { defaultHandler = h; }
    public static UncaughtExceptionHandler getDefaultUncaughtExceptionHandler() { return defaultHandler; }
}
