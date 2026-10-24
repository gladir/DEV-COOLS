package java.util;
public abstract class TimerTask implements Runnable {
    long next, period;
    boolean cancelled;
    protected TimerTask() { }
    public abstract void run();
    public boolean cancel() { boolean r = !cancelled; cancelled = true; return r; }
}
