package java.util.concurrent;
import java.util.*;
public class PriorityBlockingQueue<E> extends AbstractQueue<E> implements BlockingQueue<E> {
    private final PriorityQueue<E> q;
    public PriorityBlockingQueue() { q = new PriorityQueue<>(); }
    public PriorityBlockingQueue(int cap) { q = new PriorityQueue<>(); }
    public PriorityBlockingQueue(int cap, Comparator<? super E> c) { q = new PriorityQueue<>(cap, c); }
    public synchronized int size() { return q.size(); }
    public int remainingCapacity() { return Integer.MAX_VALUE; }
    public synchronized boolean offer(E e) { q.offer(e); notifyAll(); return true; }
    public void put(E e) { offer(e); }
    public boolean offer(E e, long t, TimeUnit u) { return offer(e); }
    public synchronized E take() throws InterruptedException { while (q.isEmpty()) wait(); return q.poll(); }
    public synchronized E poll() { return q.poll(); }
    public synchronized E poll(long timeout, TimeUnit unit) throws InterruptedException {
        long end = System.currentTimeMillis() + unit.toMillis(timeout);
        while (q.isEmpty()) { long left = end - System.currentTimeMillis(); if (left <= 0) return null; wait(left); }
        return q.poll();
    }
    public synchronized E peek() { return q.peek(); }
    public synchronized int drainTo(Collection<? super E> c) { int n = 0; while (!q.isEmpty()) { c.add(q.poll()); n++; } return n; }
    public synchronized Iterator<E> iterator() { return new ArrayList<E>(q).iterator(); }
}
