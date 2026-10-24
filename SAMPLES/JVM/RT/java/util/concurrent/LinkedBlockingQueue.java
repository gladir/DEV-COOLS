package java.util.concurrent;
import java.util.*;
public class LinkedBlockingQueue<E> extends AbstractQueue<E> implements BlockingQueue<E> {
    private final LinkedList<E> q = new LinkedList<>();
    private final int cap;
    public LinkedBlockingQueue() { this(Integer.MAX_VALUE); }
    public LinkedBlockingQueue(int capacity) { cap = capacity; }
    public LinkedBlockingQueue(Collection<? extends E> c) { this(Integer.MAX_VALUE); q.addAll(c); }
    public synchronized int size() { return q.size(); }
    public synchronized int remainingCapacity() { return cap - q.size(); }
    public synchronized boolean offer(E e) { if (e == null) throw new NullPointerException(); if (q.size() >= cap) return false; q.add(e); notifyAll(); return true; }
    public synchronized void put(E e) throws InterruptedException { if (e == null) throw new NullPointerException(); while (q.size() >= cap) wait(); q.add(e); notifyAll(); }
    public synchronized boolean offer(E e, long timeout, TimeUnit unit) throws InterruptedException {
        long end = System.currentTimeMillis() + unit.toMillis(timeout);
        while (q.size() >= cap) { long left = end - System.currentTimeMillis(); if (left <= 0) return false; wait(left); }
        q.add(e); notifyAll(); return true;
    }
    public synchronized E take() throws InterruptedException { while (q.isEmpty()) wait(); E e = q.removeFirst(); notifyAll(); return e; }
    public synchronized E poll() { if (q.isEmpty()) return null; E e = q.removeFirst(); notifyAll(); return e; }
    public synchronized E poll(long timeout, TimeUnit unit) throws InterruptedException {
        long end = System.currentTimeMillis() + unit.toMillis(timeout);
        while (q.isEmpty()) { long left = end - System.currentTimeMillis(); if (left <= 0) return null; wait(left); }
        E e = q.removeFirst(); notifyAll(); return e;
    }
    public synchronized E peek() { return q.peek(); }
    public synchronized int drainTo(Collection<? super E> c) { int n = q.size(); c.addAll(q); q.clear(); notifyAll(); return n; }
    public synchronized Iterator<E> iterator() { return new ArrayList<E>(q).iterator(); }
    public synchronized boolean remove(Object o) { boolean r = q.remove(o); notifyAll(); return r; }
    public synchronized boolean contains(Object o) { return q.contains(o); }
    public synchronized void clear() { q.clear(); notifyAll(); }
    public synchronized String toString() { return q.toString(); }
}
