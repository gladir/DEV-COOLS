package java.util.concurrent;
public class Semaphore implements java.io.Serializable {
    private static final long serialVersionUID = -3222578661600680210L;
    private int permits;
    public Semaphore(int permits) { this.permits = permits; }
    public Semaphore(int permits, boolean fair) { this.permits = permits; }
    public synchronized void acquire() throws InterruptedException { while (permits <= 0) wait(); permits--; }
    public synchronized void acquire(int n) throws InterruptedException { while (permits < n) wait(); permits -= n; }
    public synchronized void acquireUninterruptibly() { while (permits <= 0) { try { wait(); } catch (InterruptedException e) { } } permits--; }
    public synchronized boolean tryAcquire() { if (permits > 0) { permits--; return true; } return false; }
    public synchronized boolean tryAcquire(long timeout, TimeUnit unit) throws InterruptedException {
        long end = System.currentTimeMillis() + unit.toMillis(timeout);
        while (permits <= 0) { long left = end - System.currentTimeMillis(); if (left <= 0) return false; wait(left); }
        permits--; return true;
    }
    public synchronized void release() { permits++; notifyAll(); }
    public synchronized void release(int n) { permits += n; notifyAll(); }
    public synchronized int availablePermits() { return permits; }
}
