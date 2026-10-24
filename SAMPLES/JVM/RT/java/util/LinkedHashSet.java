package java.util;
public class LinkedHashSet<E> extends HashSet<E> implements Set<E>, Cloneable, java.io.Serializable {
    private static final long serialVersionUID = -2851667679971038690L;
    public LinkedHashSet(int initialCapacity, float loadFactor) { super(initialCapacity, loadFactor, true); }
    public LinkedHashSet(int initialCapacity) { super(initialCapacity, .75f, true); }
    public LinkedHashSet() { super(16, .75f, true); }
    public LinkedHashSet(Collection<? extends E> c) { super(Math.max(2 * c.size(), 11), .75f, true); addAll(c); }
    public E getFirst() { return iterator().next(); }
    public E getLast() { E r = null; for (E e : this) r = e; if (r == null) throw new NoSuchElementException(); return r; }
}
