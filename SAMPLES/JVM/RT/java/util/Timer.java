package java.util;
public class Timer {
    private final Thread thread;
    private final ArrayList<TimerTask> tasks = new ArrayList<>();
    private boolean cancelled;
    public Timer() { this("Timer-0", false); }
    public Timer(boolean daemon) { this("Timer-0", daemon); }
    public Timer(String name) { this(name, false); }
    public Timer(String name, boolean daemon) {
        thread = new Thread(() -> loop(), name);
        thread.setDaemon(daemon);
        thread.start();
    }
    private synchronized void loop() {
        while (true) {
            if (cancelled) return;
            TimerTask next = null;
            for (TimerTask t : tasks) if (!t.cancelled && (next == null || t.next < next.next)) next = t;
            if (next == null) { try { wait(); } catch (InterruptedException e) { return; } continue; }
            long now = System.currentTimeMillis();
            if (next.next > now) { try { wait(next.next - now); } catch (InterruptedException e) { return; } continue; }
            if (next.period > 0) next.next += next.period; else { next.cancelled = true; }
            tasks.removeIf(t -> t.cancelled);
            next.run();
        }
    }
    public synchronized void schedule(TimerTask t, long delay) { t.next = System.currentTimeMillis() + delay; tasks.add(t); notifyAll(); }
    public synchronized void schedule(TimerTask t, long delay, long period) { t.next = System.currentTimeMillis() + delay; t.period = period; tasks.add(t); notifyAll(); }
    public synchronized void scheduleAtFixedRate(TimerTask t, long delay, long period) { schedule(t, delay, period); }
    public synchronized void cancel() { cancelled = true; notifyAll(); }
}
