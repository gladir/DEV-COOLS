package java.util.concurrent;
import java.util.*;
public class CopyOnWriteArraySet<E> extends AbstractSet<E> implements java.io.Serializable {
    private static final long serialVersionUID = 5457747651344034263L;
    private final CopyOnWriteArrayList<E> l = new CopyOnWriteArrayList<>();
    public CopyOnWriteArraySet() { }
    public CopyOnWriteArraySet(Collection<? extends E> c) { for (E e : c) l.addIfAbsent(e); }
    public int size() { return l.size(); }
    public boolean add(E e) { return l.addIfAbsent(e); }
    public boolean contains(Object o) { return l.contains(o); }
    public boolean remove(Object o) { return l.remove(o); }
    public Iterator<E> iterator() { return l.iterator(); }
}
