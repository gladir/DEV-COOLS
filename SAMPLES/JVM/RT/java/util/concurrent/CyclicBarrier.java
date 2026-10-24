package java.util.concurrent;
public class CyclicBarrier {
    private final int parties;
    private final Runnable action;
    private int waiting, generation;
    public CyclicBarrier(int parties) { this(parties, null); }
    public CyclicBarrier(int parties, Runnable action) { this.parties = parties; this.action = action; }
    public synchronized int await() throws InterruptedException, BrokenBarrierException {
        int idx = parties - 1 - waiting;
        waiting++;
        if (waiting == parties) { if (action != null) action.run(); waiting = 0; generation++; notifyAll(); return 0; }
        int g = generation;
        while (g == generation) wait();
        return idx;
    }
    public int getParties() { return parties; }
    public synchronized int getNumberWaiting() { return waiting; }
}
