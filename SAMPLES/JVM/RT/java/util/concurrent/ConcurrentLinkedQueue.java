package java.util.concurrent;
import java.util.*;
public class ConcurrentLinkedQueue<E> extends AbstractQueue<E> {
    private final LinkedList<E> q = new LinkedList<>();
    public ConcurrentLinkedQueue() { }
    public ConcurrentLinkedQueue(Collection<? extends E> c) { q.addAll(c); }
    public synchronized boolean offer(E e) { if (e == null) throw new NullPointerException(); return q.add(e); }
    public synchronized E poll() { return q.poll(); }
    public synchronized E peek() { return q.peek(); }
    public synchronized int size() { return q.size(); }
    public synchronized Iterator<E> iterator() { return new ArrayList<E>(q).iterator(); }
    public synchronized boolean remove(Object o) { return q.remove(o); }
    public synchronized boolean contains(Object o) { return q.contains(o); }
}
