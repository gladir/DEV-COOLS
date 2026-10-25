package java.util;
public class HashSet<E> extends AbstractSet<E> implements Set<E>, Cloneable, java.io.Serializable {
    private static final long serialVersionUID = -5024744406713321676L;
    transient HashMap<E, Object> map;
    static final Object PRESENT = new Object();
    public HashSet() { map = new HashMap<>(); }
    public HashSet(Collection<? extends E> c) { map = new HashMap<>(Math.max((int) (c.size() / .75f) + 1, 16)); addAll(c); }
    public HashSet(int initialCapacity, float loadFactor) { map = new HashMap<>(initialCapacity, loadFactor); }
    public HashSet(int initialCapacity) { map = new HashMap<>(initialCapacity); }
    HashSet(int initialCapacity, float loadFactor, boolean dummy) { map = new LinkedHashMap<>(initialCapacity, loadFactor); }
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        s.defaultWriteObject();
        s.writeInt(map.capacity());
        s.writeFloat(map.loadFactor());
        s.writeInt(map.size());
        for (E e : map.keySet()) s.writeObject(e);
    }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        int capacity = s.readInt();
        if (capacity < 0) throw new java.io.InvalidObjectException("Illegal capacity: " + capacity);
        float loadFactor = s.readFloat();
        if (loadFactor <= 0 || Float.isNaN(loadFactor)) throw new java.io.InvalidObjectException("Illegal load factor: " + loadFactor);
        int size = s.readInt();
        if (size < 0) throw new java.io.InvalidObjectException("Illegal size: " + size);
        capacity = (int) Math.min(size * Math.min(1 / loadFactor, 4.0f), 1073741824);
        map = (((HashSet<?>) this) instanceof LinkedHashSet ? new LinkedHashMap<E, Object>(capacity, loadFactor) : new HashMap<E, Object>(capacity, loadFactor));
        for (int i = 0; i < size; i++) {
            E e = (E) s.readObject();
            map.put(e, PRESENT);
        }
    }
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
