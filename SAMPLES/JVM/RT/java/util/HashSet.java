package java.util;
public class HashSet<E> extends AbstractSet<E> implements Set<E>, Cloneable, java.io.Serializable {
    transient HashMap<E, Object> map;
    static final Object PRESENT = new Object();
    public HashSet() { map = new HashMap<>(); }
    public HashSet(Collection<? extends E> c) { map = new HashMap<>(Math.max((int) (c.size() / .75f) + 1, 16)); addAll(c); }
    public HashSet(int initialCapacity, float loadFactor) { map = new HashMap<>(initialCapacity, loadFactor); }
    public HashSet(int initialCapacity) { map = new HashMap<>(initialCapacity); }
    HashSet(int initialCapacity, float loadFactor, boolean dummy) { map = new LinkedHashMap<>(initialCapacity, loadFactor); }
    public Iterator<E> iterator() { return map.keySet().iterator(); }
    public int size() { return map.size(); }
    public boolean isEmpty() { return map.isEmpty(); }
    public boolean contains(Object o) { return map.containsKey(o); }
    public boolean add(E e) { return map.put(e, PRESENT) == null; }
    public boolean remove(Object o) { return map.remove(o) == PRESENT; }
    public void clear() { map.clear(); }
    public Object clone() { HashSet<E> n = new HashSet<>(); n.addAll(this); return n; }
    public Object[] toArray() { return map.keySet().toArray(); }
    public <T> T[] toArray(T[] a) { return map.keySet().toArray(a); }
    public static <T> HashSet<T> newHashSet(int n) { return new HashSet<>((int) Math.ceil(n / 0.75)); }
}
