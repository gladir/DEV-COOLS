package java.util;
public class TreeSet<E> extends AbstractSet<E> implements NavigableSet<E>, Cloneable, java.io.Serializable {
    private static final long serialVersionUID = -2479143000061671589L;
    private transient TreeMap<E, Object> m;
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        s.defaultWriteObject();
        s.writeObject(m.comparator());
        s.writeInt(m.size());
        for (E e : m.keySet()) s.writeObject(e);
    }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        Comparator<? super E> c = (Comparator<? super E>) s.readObject();
        m = new TreeMap<E, Object>(c);
        int size = s.readInt();
        for (int i = 0; i < size; i++) m.put((E) s.readObject(), PRESENT);
    }
    private static final Object PRESENT = new Object();
    public TreeSet() { m = new TreeMap<>(); }
    public TreeSet(Comparator<? super E> comparator) { m = new TreeMap<>(comparator); }
    public TreeSet(Collection<? extends E> c) { m = new TreeMap<>(); addAll(c); }
    public TreeSet(SortedSet<E> s) { m = new TreeMap<>(s.comparator()); addAll(s); }
    TreeSet(TreeMap<E, ?> map) { m = (TreeMap<E, Object>) map; }
    public Iterator<E> iterator() { return m.keySet().iterator(); }
    public Iterator<E> descendingIterator() { return descendingSet().iterator(); }
    public NavigableSet<E> descendingSet() { return new TreeSet<E>((TreeMap<E, Object>) m.descendingMap()); }
    public int size() { return m.size(); }
    public boolean isEmpty() { return m.isEmpty(); }
    public boolean contains(Object o) { return m.containsKey(o); }
    public boolean add(E e) { return m.put(e, PRESENT) == null; }
    public boolean remove(Object o) { return m.remove(o) == PRESENT; }
    public void clear() { m.clear(); }
    public NavigableSet<E> subSet(E fromElement, boolean fromInclusive, E toElement, boolean toInclusive) { return new TreeSet<E>((TreeMap<E, Object>) m.subMap(fromElement, fromInclusive, toElement, toInclusive)); }
    public NavigableSet<E> headSet(E toElement, boolean inclusive) { return new TreeSet<E>((TreeMap<E, Object>) m.headMap(toElement, inclusive)); }
    public NavigableSet<E> tailSet(E fromElement, boolean inclusive) { return new TreeSet<E>((TreeMap<E, Object>) m.tailMap(fromElement, inclusive)); }
    public SortedSet<E> subSet(E fromElement, E toElement) { return subSet(fromElement, true, toElement, false); }
    public SortedSet<E> headSet(E toElement) { return headSet(toElement, false); }
    public SortedSet<E> tailSet(E fromElement) { return tailSet(fromElement, true); }
    public Comparator<? super E> comparator() { return m.comparator(); }
    public E first() { return m.firstKey(); }
    public E last() { return m.lastKey(); }
    public E lower(E e) { return m.lowerKey(e); }
    public E floor(E e) { return m.floorKey(e); }
    public E ceiling(E e) { return m.ceilingKey(e); }
    public E higher(E e) { return m.higherKey(e); }
    public E pollFirst() { Map.Entry<E, ?> e = m.pollFirstEntry(); return (e == null) ? null : e.getKey(); }
    public E pollLast() { Map.Entry<E, ?> e = m.pollLastEntry(); return (e == null) ? null : e.getKey(); }
    public Object clone() { TreeSet<E> t = new TreeSet<>(m.comparator()); t.addAll(this); return t; }
    public E getFirst() { return first(); }
    public E getLast() { return last(); }
}
