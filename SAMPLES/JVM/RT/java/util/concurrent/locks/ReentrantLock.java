package java.util.concurrent.locks;
import java.util.concurrent.TimeUnit;
public class ReentrantLock implements Lock {
    private static final long serialVersionUID = 7373984872572414699L;
    private Thread owner;
    private int holds;
    public ReentrantLock() { }
    public ReentrantLock(boolean fair) { }
    public synchronized void lock() {
        Thread me = Thread.currentThread();
        if (owner == me) { holds++; return; }
        while (owner != null) { try { wait(); } catch (InterruptedException e) { } }
        owner = me; holds = 1;
    }
    public synchronized void lockInterruptibly() throws InterruptedException {
        Thread me = Thread.currentThread();
        if (owner == me) { holds++; return; }
        while (owner != null) wait();
        owner = me; holds = 1;
    }
    public synchronized boolean tryLock() {
        Thread me = Thread.currentThread();
        if (owner == me) { holds++; return true; }
        if (owner != null) return false;
        owner = me; holds = 1; return true;
    }
    public synchronized boolean tryLock(long time, TimeUnit unit) throws InterruptedException {
        Thread me = Thread.currentThread();
        if (owner == me) { holds++; return true; }
        long end = System.currentTimeMillis() + unit.toMillis(time);
        while (owner != null) { long left = end - System.currentTimeMillis(); if (left <= 0) return false; wait(left); }
        owner = me; holds = 1; return true;
    }
    public synchronized void unlock() {
        if (owner != Thread.currentThread()) throw new IllegalMonitorStateException();
        if (--holds == 0) { owner = null; notifyAll(); }
    }
    public synchronized boolean isLocked() { return owner != null; }
    public synchronized boolean isHeldByCurrentThread() { return owner == Thread.currentThread(); }
    public synchronized int getHoldCount() { return owner == Thread.currentThread() ? holds : 0; }
    public Condition newCondition() { return new Cond(); }
    private class Cond implements Condition {
        private int signals;
        private int waiters;
        public void await() throws InterruptedException { await0(0); }
        private boolean await0(long ms) throws InterruptedException {
            if (owner != Thread.currentThread()) throw new IllegalMonitorStateException();
            int saved;
            synchronized (ReentrantLock.this) { saved = holds; holds = 0; owner = null; ReentrantLock.this.notifyAll(); }
            boolean got;
            synchronized (this) {
                waiters++;
                long end = System.currentTimeMillis() + ms;
                try {
                    while (signals == 0) {
                        if (ms > 0) { long left = end - System.currentTimeMillis(); if (left <= 0) break; wait(left); } else wait();
                    }
                } catch (InterruptedException e) { waiters--; relock(saved); throw e; }
                got = signals > 0;
                if (got) signals--;
                waiters--;
            }
            relock(saved);
            return got;
        }
        private void relock(int saved) {
            synchronized (ReentrantLock.this) {
                Thread me = Thread.currentThread();
                while (owner != null) { try { ReentrantLock.this.wait(); } catch (InterruptedException e) { } }
                owner = me; holds = saved;
            }
        }
        public boolean await(long time, TimeUnit unit) throws InterruptedException { return await0(Math.max(1, unit.toMillis(time))); }
        public long awaitNanos(long nanos) throws InterruptedException { return await0(Math.max(1, nanos / 1000000)) ? 1 : 0; }
        public synchronized void signal() { if (waiters > signals) { signals++; notifyAll(); } }
        public synchronized void signalAll() { signals = waiters; notifyAll(); }
    }
}
