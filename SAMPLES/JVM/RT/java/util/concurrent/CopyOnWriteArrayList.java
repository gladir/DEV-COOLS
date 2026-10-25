package java.util.concurrent;
import java.util.*;
public class CopyOnWriteArrayList<E> extends AbstractList<E> implements RandomAccess, java.io.Serializable {
    private static final long serialVersionUID = 8673264195747942595L;
    private volatile Object[] a = new Object[0];
    public CopyOnWriteArrayList() { }
    public CopyOnWriteArrayList(Collection<? extends E> c) { a = c.toArray(); }
    public CopyOnWriteArrayList(E[] arr) { a = arr.clone(); }
    public int size() { return a.length; }
    public E get(int i) { return (E) a[i]; }
    public synchronized E set(int i, E e) { Object[] n = a.clone(); E old = (E) n[i]; n[i] = e; a = n; return old; }
    public synchronized boolean add(E e) { Object[] n = Arrays.copyOf(a, a.length + 1); n[a.length] = e; a = n; return true; }
    public synchronized void add(int i, E e) { Object[] n = new Object[a.length + 1]; System.arraycopy(a, 0, n, 0, i); n[i] = e; System.arraycopy(a, i, n, i + 1, a.length - i); a = n; }
    public synchronized E remove(int i) { E old = (E) a[i]; Object[] n = new Object[a.length - 1]; System.arraycopy(a, 0, n, 0, i); System.arraycopy(a, i + 1, n, i, a.length - i - 1); a = n; return old; }
    public synchronized boolean addIfAbsent(E e) { if (contains(e)) return false; return add(e); }
    public Iterator<E> iterator() { final Object[] snap = a; return new Iterator<E>() { int i = 0; public boolean hasNext() { return i < snap.length; } public E next() { if (i >= snap.length) throw new NoSuchElementException(); return (E) snap[i++]; } }; }
}
