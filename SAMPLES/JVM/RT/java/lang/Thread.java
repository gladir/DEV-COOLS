package java.lang;
public class Thread implements Runnable {
    private static Thread mainThread;
    private static int counter = 0;
    private Runnable target;
    private String name;
    private boolean started, daemon, interrupted;
    private int priority = 5;
    private long id;
    public static final int MIN_PRIORITY = 1, NORM_PRIORITY = 5, MAX_PRIORITY = 10;
    public Thread() { this(null, null); }
    public Thread(Runnable target) { this(target, null); }
    public Thread(String name) { this(null, name); }
    public Thread(Runnable target, String name) {
        this.target = target;
        this.id = ++counter;
        this.name = name != null ? name : "Thread-" + (counter - 2);
    }
    public static Thread currentThread() {
        if (mainThread == null) { mainThread = new Thread(null, "main"); mainThread.id = 1; counter = 1; mainThread.started = true; }
        return mainThread;
    }
    public void run() { if (target != null) target.run(); }
    public synchronized void start() {
        if (started) throw new IllegalThreadStateException();
        started = true;
        try { run(); }
        catch (Throwable t) {
            System.err.print("Exception in thread \"" + name + "\" ");
            t.printStackTrace();
        }
    }
    public final void join() throws InterruptedException { }
    public final void join(long ms) throws InterruptedException { }
    public static void sleep(long ms) throws InterruptedException {
        if (VM.pumpHook != null) {
            long end = System.currentTimeMillis() + ms;
            do { VM.pumpHook.run(); long left = end - System.currentTimeMillis(); if (left > 0) VM.sleep(Math.min(left, 8)); } while (System.currentTimeMillis() < end);
        } else VM.sleep(ms);
    }
    public static void sleep(long ms, int nanos) throws InterruptedException { VM.sleep(ms); }
    public static void yield() { }
    public static void onSpinWait() { }
    public void interrupt() { interrupted = true; }
    public boolean isInterrupted() { return interrupted; }
    public static boolean interrupted() { boolean r = currentThread().interrupted; currentThread().interrupted = false; return r; }
    public final boolean isAlive() { return false; }
    public final boolean isDaemon() { return daemon; }
    public final void setDaemon(boolean on) { daemon = on; }
    public final String getName() { return name; }
    public final void setName(String n) { name = n; }
    public long getId() { return id; }
    public long threadId() { return id; }
    public final int getPriority() { return priority; }
    public final void setPriority(int p) { priority = p; }
    public StackTraceElement[] getStackTrace() { return new StackTraceElement[0]; }
    public String toString() { return "Thread[#" + id + "," + name + "," + priority + ",main]"; }
    public static Thread startVirtualThread(Runnable r) { Thread t = new Thread(r); t.start(); return t; }
    public static boolean holdsLock(Object o) { return true; }
    public enum State { NEW, RUNNABLE, BLOCKED, WAITING, TIMED_WAITING, TERMINATED }
    public State getState() { return started ? State.TERMINATED : State.NEW; }
    public interface UncaughtExceptionHandler { void uncaughtException(Thread t, Throwable e); }
    public void setUncaughtExceptionHandler(UncaughtExceptionHandler h) { }
}
