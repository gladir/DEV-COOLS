package java.util;
import java.util.function.*;
public class TreeMap<K, V> extends AbstractMap<K, V> implements NavigableMap<K, V>, Cloneable, java.io.Serializable {
    private static final long serialVersionUID = 919286545866124006L;
    private final Comparator<? super K> comparator;
    private transient Object[] keys = new Object[16];
    private transient Object[] vals = new Object[16];
    private transient int size;
    private transient int modCount;
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        s.defaultWriteObject();
        s.writeInt(size);
        for (int i = 0; i < size; i++) { s.writeObject(keys[i]); s.writeObject(vals[i]); }
    }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        keys = new Object[16]; vals = new Object[16]; size = 0; modCount = 0;
        int n = s.readInt();
        for (int i = 0; i < n; i++) { K k = (K) s.readObject(); V v = (V) s.readObject(); put(k, v); }
    }
    public TreeMap() { comparator = null; }
    public TreeMap(Comparator<? super K> comparator) { this.comparator = comparator; }
    public TreeMap(Map<? extends K, ? extends V> m) { comparator = null; putAll(m); }
    public TreeMap(SortedMap<K, ? extends V> m) { comparator = m.comparator(); putAll(m); }
    private int cmp(Object a, Object b) {
        return comparator != null ? comparator.compare((K) a, (K) b) : ((Comparable<Object>) a).compareTo(b);
    }
    // position de la cle ou -(point d'insertion) - 1
    private int find(Object key) {
        int lo = 0, hi = size - 1;
        while (lo <= hi) {
            int mid = (lo + hi) >>> 1;
            int c = cmp(keys[mid], key);
            if (c < 0) lo = mid + 1; else if (c > 0) hi = mid - 1; else return mid;
        }
        return -(lo + 1);
    }
    public int size() { return size; }
    public boolean containsKey(Object key) { if (key == null && comparator == null) throw new NullPointerException(); return find(key) >= 0; }
    public boolean containsValue(Object value) {
        for (int i = 0; i < size; i++) if (Objects.equals(value, vals[i])) return true;
        return false;
    }
    public V get(Object key) {
        if (key == null && comparator == null) throw new NullPointerException();
        int i = find(key);
        return i >= 0 ? (V) vals[i] : null;
    }
    public Comparator<? super K> comparator() { return comparator; }
    public K firstKey() { if (size == 0) throw new NoSuchElementException(); return (K) keys[0]; }
    public K lastKey() { if (size == 0) throw new NoSuchElementException(); return (K) keys[size - 1]; }
    public V put(K key, V value) {
        if (key == null && comparator == null) throw new NullPointerException();
        if (size == 0) cmp(key, key);
        int i = find(key);
        if (i >= 0) { V old = (V) vals[i]; vals[i] = value; return old; }
        i = -(i + 1);
        modCount++;
        if (size == keys.length) { keys = Arrays.copyOf(keys, size * 2); vals = Arrays.copyOf(vals, size * 2); }
        System.arraycopy(keys, i, keys, i + 1, size - i);
        System.arraycopy(vals, i, vals, i + 1, size - i);
        keys[i] = key; vals[i] = value;
        size++;
        return null;
    }
    private V removeAt(int i) {
        V old = (V) vals[i];
        modCount++;
        System.arraycopy(keys, i + 1, keys, i, size - i - 1);
        System.arraycopy(vals, i + 1, vals, i, size - i - 1);
        size--;
        keys[size] = null; vals[size] = null;
        return old;
    }
    public V remove(Object key) { int i = find(key); return i >= 0 ? removeAt(i) : null; }
    public void clear() { modCount++; size = 0; keys = new Object[16]; vals = new Object[16]; }
    public Object clone() { TreeMap<K, V> t = new TreeMap<>(comparator); t.putAll(this); return t; }
    private Map.Entry<K, V> entryAt(int i) { return (i < 0 || i >= size) ? null : new AbstractMap.SimpleImmutableEntry<K, V>((K) keys[i], (V) vals[i]); }
    private int lowerIdx(Object key) { int i = find(key); return i >= 0 ? i - 1 : -(i + 1) - 1; }
    private int floorIdx(Object key) { int i = find(key); return i >= 0 ? i : -(i + 1) - 1; }
    private int ceilIdx(Object key) { int i = find(key); return i >= 0 ? i : -(i + 1); }
    private int higherIdx(Object key) { int i = find(key); return i >= 0 ? i + 1 : -(i + 1); }
    public Map.Entry<K, V> firstEntry() { return entryAt(0); }
    public Map.Entry<K, V> lastEntry() { return entryAt(size - 1); }
    public Map.Entry<K, V> lowerEntry(K key) { return entryAt(lowerIdx(key)); }
    public K lowerKey(K key) { int i = lowerIdx(key); return i < 0 ? null : (K) keys[i]; }
    public Map.Entry<K, V> floorEntry(K key) { return entryAt(floorIdx(key)); }
    public K floorKey(K key) { int i = floorIdx(key); return i < 0 ? null : (K) keys[i]; }
    public Map.Entry<K, V> ceilingEntry(K key) { return entryAt(ceilIdx(key)); }
    public K ceilingKey(K key) { int i = ceilIdx(key); return i >= size ? null : (K) keys[i]; }
    public Map.Entry<K, V> higherEntry(K key) { return entryAt(higherIdx(key)); }
    public K higherKey(K key) { int i = higherIdx(key); return i >= size ? null : (K) keys[i]; }
    public Map.Entry<K, V> pollFirstEntry() { Map.Entry<K, V> e = entryAt(0); if (e != null) removeAt(0); return e; }
    public Map.Entry<K, V> pollLastEntry() { Map.Entry<K, V> e = entryAt(size - 1); if (e != null) removeAt(size - 1); return e; }
    private TreeMap<K, V> range(int from, int to) {
        TreeMap<K, V> t = new TreeMap<>(comparator);
        for (int i = from; i < to; i++) t.put((K) keys[i], (V) vals[i]);
        return t;
    }
    public NavigableMap<K, V> subMap(K fromKey, boolean fromInclusive, K toKey, boolean toInclusive) {
        if (cmp(fromKey, toKey) > 0) throw new IllegalArgumentException("fromKey > toKey");
        return range(fromInclusive ? ceilIdx(fromKey) : higherIdx(fromKey), toInclusive ? floorIdx(toKey) + 1 : lowerIdx(toKey) + 1);
    }
    public NavigableMap<K, V> headMap(K toKey, boolean inclusive) { return range(0, inclusive ? floorIdx(toKey) + 1 : lowerIdx(toKey) + 1); }
    public NavigableMap<K, V> tailMap(K fromKey, boolean inclusive) { return range(inclusive ? ceilIdx(fromKey) : higherIdx(fromKey), size); }
    public SortedMap<K, V> subMap(K fromKey, K toKey) { return subMap(fromKey, true, toKey, false); }
    public SortedMap<K, V> headMap(K toKey) { return headMap(toKey, false); }
    public SortedMap<K, V> tailMap(K fromKey) { return tailMap(fromKey, true); }
    public NavigableMap<K, V> descendingMap() {
        TreeMap<K, V> t = new TreeMap<>(Collections.reverseOrder(comparator));
        for (int i = 0; i < size; i++) t.put((K) keys[i], (V) vals[i]);
        return t;
    }
    public NavigableSet<K> navigableKeySet() { return new TreeSet<K>(this); }
    public NavigableSet<K> descendingKeySet() { return descendingMap().navigableKeySet(); }
    public Set<K> keySet() {
        return new AbstractSet<K>() {
            public Iterator<K> iterator() { return new TIter<K>(0); }
            public int size() { return size; }
            public boolean contains(Object o) { return containsKey(o); }
            public boolean remove(Object o) { int i = find(o); if (i < 0) return false; removeAt(i); return true; }
            public void clear() { TreeMap.this.clear(); }
        };
    }
    public Collection<V> values() {
        return new AbstractCollection<V>() {
            public Iterator<V> iterator() { return new TIter<V>(1); }
            public int size() { return size; }
            public void clear() { TreeMap.this.clear(); }
        };
    }
    public Set<Map.Entry<K, V>> entrySet() {
        return new AbstractSet<Map.Entry<K, V>>() {
            public Iterator<Map.Entry<K, V>> iterator() { return new TIter<Map.Entry<K, V>>(2); }
            public int size() { return size; }
            public void clear() { TreeMap.this.clear(); }
        };
    }
    private class TIter<T> implements Iterator<T> {
        int idx = 0, last = -1, kind, expected = modCount;
        TIter(int kind) { this.kind = kind; }
        public boolean hasNext() { return idx < size; }
        public T next() {
            if (expected != modCount) throw new ConcurrentModificationException();
            if (idx >= size) throw new NoSuchElementException();
            last = idx++;
            if (kind == 0) return (T) keys[last];
            if (kind == 1) return (T) vals[last];
            return (T) new EntryView(last);
        }
        public void remove() {
            if (last < 0) throw new IllegalStateException();
            if (expected != modCount) throw new ConcurrentModificationException();
            removeAt(last);
            idx = last; last = -1;
            expected = modCount;
        }
    }
    private class EntryView implements Map.Entry<K, V> {
        final K k; V v;
        EntryView(int i) { k = (K) keys[i]; v = (V) vals[i]; }
        public K getKey() { return k; }
        public V getValue() { return v; }
        public V setValue(V nv) { V o = v; v = nv; TreeMap.this.put(k, nv); return o; }
        public boolean equals(Object o) { return o instanceof Map.Entry<?, ?> e && Objects.equals(k, e.getKey()) && Objects.equals(v, e.getValue()); }
        public int hashCode() { return Objects.hashCode(k) ^ Objects.hashCode(v); }
        public String toString() { return k + "=" + v; }
    }
    public void forEach(BiConsumer<? super K, ? super V> action) {
        int expected = modCount;
        for (int i = 0; i < size; i++) { action.accept((K) keys[i], (V) vals[i]); if (expected != modCount) throw new ConcurrentModificationException(); }
    }
}
