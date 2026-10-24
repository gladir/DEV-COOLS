package java.util;
import java.util.function.*;
public class Hashtable<K, V> extends Dictionary<K, V> implements Map<K, V>, Cloneable, java.io.Serializable {
    private static final long serialVersionUID = 1421746759512286392L;
    private static class Entry<K, V> implements Map.Entry<K, V> {
        final int hash; final K key; V value; Entry<K, V> next;
        Entry(int hash, K key, V value, Entry<K, V> next) { this.hash = hash; this.key = key; this.value = value; this.next = next; }
        public K getKey() { return key; }
        public V getValue() { return value; }
        public V setValue(V v) { if (v == null) throw new NullPointerException(); V o = value; value = v; return o; }
        public boolean equals(Object o) { return o instanceof Map.Entry<?, ?> e && (key == null ? e.getKey() == null : key.equals(e.getKey())) && (value == null ? e.getValue() == null : value.equals(e.getValue())); }
        public int hashCode() { return hash ^ Objects.hashCode(value); }
        public String toString() { return key.toString() + "=" + value.toString(); }
    }
    private transient Entry<?, ?>[] table;
    private transient int count;
    private int threshold;
    private float loadFactor;
    private transient int modCount;
    void defaultWriteHashtable(java.io.ObjectOutputStream s, int length, float loadFactor) throws java.io.IOException {
        int origThreshold = this.threshold;
        float origLoadFactor = this.loadFactor;
        this.threshold = (int) Math.min(length * loadFactor, Integer.MAX_VALUE - 8 + 1);
        this.loadFactor = loadFactor;
        s.defaultWriteObject();
        this.threshold = origThreshold;
        this.loadFactor = origLoadFactor;
    }
    void writeHashtable(java.io.ObjectOutputStream s) throws java.io.IOException {
        Entry<Object, Object> entryStack = null;
        synchronized (this) {
            s.defaultWriteObject();
            s.writeInt(table.length);
            s.writeInt(count);
            for (int index = 0; index < table.length; index++) {
                Entry<?, ?> entry = table[index];
                while (entry != null) {
                    entryStack = new Entry<Object, Object>(0, entry.key, entry.value, entryStack);
                    entry = entry.next;
                }
            }
        }
        while (entryStack != null) {
            s.writeObject(entryStack.key);
            s.writeObject(entryStack.value);
            entryStack = entryStack.next;
        }
    }
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException { writeHashtable(s); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException { readHashtable(s); }
    void readHashtable(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        if (loadFactor <= 0 || Float.isNaN(loadFactor)) throw new java.io.StreamCorruptedException("Illegal Load: " + loadFactor);
        int origlength = s.readInt();
        int elements = s.readInt();
        if (elements < 0) throw new java.io.StreamCorruptedException("Illegal # of Elements: " + elements);
        origlength = Math.max(origlength, (int) (elements / loadFactor) + 1);
        int length = (int) ((elements + elements / 20) / loadFactor) + 3;
        if (length > elements && (length & 1) == 0) length--;
        length = Math.min(length, origlength);
        if (length < 0) length = origlength;
        table = new Entry<?, ?>[length];
        threshold = (int) Math.min(length * loadFactor, Integer.MAX_VALUE - 8 + 1);
        count = 0;
        for (; elements > 0; elements--) {
            K key = (K) s.readObject();
            V value = (V) s.readObject();
            reconstitutionPut(table, key, value);
        }
    }
    private void reconstitutionPut(Entry<?, ?>[] tab, K key, V value) throws java.io.StreamCorruptedException {
        if (value == null) throw new java.io.StreamCorruptedException();
        int hash = key.hashCode();
        int index = (hash & 0x7FFFFFFF) % tab.length;
        for (Entry<?, ?> e = tab[index]; e != null; e = e.next) {
            if ((e.hash == hash) && e.key.equals(key)) throw new java.io.StreamCorruptedException();
        }
        Entry<K, V> e = (Entry<K, V>) tab[index];
        tab[index] = new Entry<>(hash, key, value, e);
        count++;
    }
    public Hashtable(int initialCapacity, float loadFactor) {
        if (initialCapacity < 0) throw new IllegalArgumentException("Illegal Capacity: " + initialCapacity);
        if (initialCapacity == 0) initialCapacity = 1;
        this.loadFactor = loadFactor;
        table = new Entry<?, ?>[initialCapacity];
        threshold = (int) Math.min(initialCapacity * loadFactor, Integer.MAX_VALUE - 8 + 1);
    }
    public Hashtable(int initialCapacity) { this(initialCapacity, 0.75f); }
    public Hashtable() { this(11, 0.75f); }
    public Hashtable(Map<? extends K, ? extends V> t) { this(Math.max(2 * t.size(), 11), 0.75f); putAll(t); }
    public synchronized int size() { return count; }
    public synchronized boolean isEmpty() { return count == 0; }
    public synchronized Enumeration<K> keys() { return Collections.enumeration(keySet()); }
    public synchronized Enumeration<V> elements() { return Collections.enumeration(values()); }
    public synchronized boolean contains(Object value) {
        if (value == null) throw new NullPointerException();
        Entry<?, ?>[] tab = table;
        for (int i = tab.length; i-- > 0; ) for (Entry<?, ?> e = tab[i]; e != null; e = e.next) if (e.value.equals(value)) return true;
        return false;
    }
    public boolean containsValue(Object value) { return contains(value); }
    public synchronized boolean containsKey(Object key) {
        Entry<?, ?>[] tab = table;
        int hash = key.hashCode();
        int index = (hash & 0x7FFFFFFF) % tab.length;
        for (Entry<?, ?> e = tab[index]; e != null; e = e.next) if ((e.hash == hash) && e.key.equals(key)) return true;
        return false;
    }
    public synchronized V get(Object key) {
        Entry<?, ?>[] tab = table;
        int hash = key.hashCode();
        int index = (hash & 0x7FFFFFFF) % tab.length;
        for (Entry<?, ?> e = tab[index]; e != null; e = e.next) if ((e.hash == hash) && e.key.equals(key)) return (V) e.value;
        return null;
    }
    protected void rehash() {
        int oldCapacity = table.length;
        Entry<?, ?>[] oldMap = table;
        int newCapacity = (oldCapacity << 1) + 1;
        Entry<?, ?>[] newMap = new Entry<?, ?>[newCapacity];
        modCount++;
        threshold = (int) Math.min(newCapacity * loadFactor, Integer.MAX_VALUE - 8 + 1);
        table = newMap;
        for (int i = oldCapacity; i-- > 0; ) {
            for (Entry<K, V> old = (Entry<K, V>) oldMap[i]; old != null; ) {
                Entry<K, V> e = old;
                old = old.next;
                int index = (e.hash & 0x7FFFFFFF) % newCapacity;
                e.next = (Entry<K, V>) newMap[index];
                newMap[index] = e;
            }
        }
    }
    public synchronized V put(K key, V value) {
        if (value == null) throw new NullPointerException();
        Entry<?, ?>[] tab = table;
        int hash = key.hashCode();
        int index = (hash & 0x7FFFFFFF) % tab.length;
        Entry<K, V> entry = (Entry<K, V>) tab[index];
        for (; entry != null; entry = entry.next) {
            if ((entry.hash == hash) && entry.key.equals(key)) { V old = entry.value; entry.value = value; return old; }
        }
        if (count >= threshold) { rehash(); tab = table; index = (hash & 0x7FFFFFFF) % tab.length; }
        Entry<K, V> e = (Entry<K, V>) tab[index];
        tab[index] = new Entry<>(hash, key, value, e);
        count++;
        modCount++;
        return null;
    }
    public synchronized V remove(Object key) {
        Entry<?, ?>[] tab = table;
        int hash = key.hashCode();
        int index = (hash & 0x7FFFFFFF) % tab.length;
        Entry<K, V> e = (Entry<K, V>) tab[index];
        for (Entry<K, V> prev = null; e != null; prev = e, e = e.next) {
            if ((e.hash == hash) && e.key.equals(key)) {
                if (prev != null) prev.next = e.next; else tab[index] = e.next;
                modCount++; count--;
                V oldValue = e.value; e.value = null;
                return oldValue;
            }
        }
        return null;
    }
    public synchronized void putAll(Map<? extends K, ? extends V> t) { for (Map.Entry<? extends K, ? extends V> e : t.entrySet()) put(e.getKey(), e.getValue()); }
    public synchronized void clear() { Entry<?, ?>[] tab = table; for (int index = tab.length; --index >= 0; ) tab[index] = null; modCount++; count = 0; }
    public synchronized String toString() {
        int max = size() - 1;
        if (max == -1) return "{}";
        StringBuilder sb = new StringBuilder();
        Iterator<Map.Entry<K, V>> it = entrySet().iterator();
        sb.append('{');
        for (int i = 0; ; i++) {
            Map.Entry<K, V> e = it.next();
            K key = e.getKey(); V value = e.getValue();
            sb.append(key == this ? "(this Map)" : key.toString()); sb.append('='); sb.append(value == this ? "(this Map)" : value.toString());
            if (i == max) return sb.append('}').toString();
            sb.append(", ");
        }
    }
    private <T> List<T> snapshot(int kind) {
        ArrayList<T> l = new ArrayList<>();
        Entry<?, ?>[] tab = table;
        for (int i = tab.length; i-- > 0; ) for (Entry<?, ?> e = tab[i]; e != null; e = e.next) l.add(kind == 0 ? (T) e.key : kind == 1 ? (T) e.value : (T) e);
        return l;
    }
    public Set<K> keySet() {
        return new AbstractSet<K>() {
            public Iterator<K> iterator() {
                final List<K> snap = Hashtable.this.snapshot(0);
                return new Iterator<K>() {
                    int i = 0; K last;
                    public boolean hasNext() { return i < snap.size(); }
                    public K next() { if (i >= snap.size()) throw new NoSuchElementException("Hashtable Enumerator"); return last = snap.get(i++); }
                    public void remove() { Hashtable.this.remove(last); }
                };
            }
            public int size() { return count; }
            public boolean contains(Object o) { return containsKey(o); }
            public boolean remove(Object o) { return Hashtable.this.remove(o) != null; }
            public void clear() { Hashtable.this.clear(); }
        };
    }
    public Set<Map.Entry<K, V>> entrySet() {
        return new AbstractSet<Map.Entry<K, V>>() {
            public Iterator<Map.Entry<K, V>> iterator() {
                final List<Map.Entry<K, V>> snap = Hashtable.this.snapshot(2);
                return new Iterator<Map.Entry<K, V>>() {
                    int i = 0; Map.Entry<K, V> last;
                    public boolean hasNext() { return i < snap.size(); }
                    public Map.Entry<K, V> next() { if (i >= snap.size()) throw new NoSuchElementException("Hashtable Enumerator"); return last = snap.get(i++); }
                    public void remove() { Hashtable.this.remove(last.getKey()); }
                };
            }
            public int size() { return count; }
            public void clear() { Hashtable.this.clear(); }
        };
    }
    public Collection<V> values() {
        return new AbstractCollection<V>() {
            public Iterator<V> iterator() {
                final List<V> snap = Hashtable.this.snapshot(1);
                return new Iterator<V>() { int i = 0; public boolean hasNext() { return i < snap.size(); } public V next() { if (i >= snap.size()) throw new NoSuchElementException("Hashtable Enumerator"); return snap.get(i++); } };
            }
            public int size() { return count; }
            public void clear() { Hashtable.this.clear(); }
        };
    }
    public synchronized boolean equals(Object o) {
        if (o == this) return true;
        if (!(o instanceof Map<?, ?> t)) return false;
        if (t.size() != count) return false;
        for (Map.Entry<K, V> e : entrySet()) if (!e.getValue().equals(t.get(e.getKey()))) return false;
        return true;
    }
    public synchronized int hashCode() { int h = 0; for (Map.Entry<K, V> e : entrySet()) h += e.hashCode(); return h; }
    public synchronized V getOrDefault(Object key, V defaultValue) { V r = get(key); return r == null ? defaultValue : r; }
    public synchronized V putIfAbsent(K key, V value) { V v = get(key); if (v == null) put(key, value); return v; }
    public synchronized V merge(K key, V value, BiFunction<? super V, ? super V, ? extends V> f) {
        V old = get(key);
        V nv = old == null ? value : f.apply(old, value);
        if (nv == null) remove(key); else put(key, nv);
        return nv;
    }
    public Object clone() { return new Hashtable<K, V>(this); }
}
