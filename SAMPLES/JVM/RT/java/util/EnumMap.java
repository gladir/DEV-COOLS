package java.util;
public class EnumMap<K extends Enum<K>, V> extends AbstractMap<K, V> implements java.io.Serializable, Cloneable {
    private final Class<K> keyType;
    private final K[] keyUniverse;
    private final Object[] vals;
    private final boolean[] has;
    private int size;
    public EnumMap(Class<K> keyType) {
        this.keyType = keyType;
        keyUniverse = keyType.getEnumConstants();
        vals = new Object[keyUniverse.length];
        has = new boolean[keyUniverse.length];
    }
    public EnumMap(Map<K, ? extends V> m) {
        this(m instanceof EnumMap ? ((EnumMap<K, ?>) m).keyType : (Class<K>) m.keySet().iterator().next().getDeclaringClass());
        putAll(m);
    }
    public int size() { return size; }
    public boolean containsValue(Object value) { for (int i = 0; i < vals.length; i++) if (has[i] && Objects.equals(value, vals[i])) return true; return false; }
    public boolean containsKey(Object key) { return key instanceof Enum<?> e && e.getDeclaringClass() == keyType && has[e.ordinal()]; }
    public V get(Object key) { return containsKey(key) ? (V) vals[((Enum<?>) key).ordinal()] : null; }
    public V put(K key, V value) {
        int i = key.ordinal();
        V old = has[i] ? (V) vals[i] : null;
        if (!has[i]) size++;
        has[i] = true; vals[i] = value;
        return old;
    }
    public V remove(Object key) {
        if (!containsKey(key)) return null;
        int i = ((Enum<?>) key).ordinal();
        V old = (V) vals[i];
        has[i] = false; vals[i] = null; size--;
        return old;
    }
    public void clear() { Arrays.fill(vals, null); Arrays.fill(has, false); size = 0; }
    public Set<Map.Entry<K, V>> entrySet() {
        return new AbstractSet<Map.Entry<K, V>>() {
            public int size() { return size; }
            public Iterator<Map.Entry<K, V>> iterator() {
                return new Iterator<Map.Entry<K, V>>() {
                    int idx = 0, last = -1;
                    { skip(); }
                    private void skip() { while (idx < has.length && !has[idx]) idx++; }
                    public boolean hasNext() { return idx < has.length; }
                    public Map.Entry<K, V> next() {
                        if (idx >= has.length) throw new NoSuchElementException();
                        last = idx++;
                        final int k = last;
                        skip();
                        return new Map.Entry<K, V>() {
                            public K getKey() { return keyUniverse[k]; }
                            public V getValue() { return (V) vals[k]; }
                            public V setValue(V v) { V o = (V) vals[k]; vals[k] = v; return o; }
                            public String toString() { return keyUniverse[k] + "=" + vals[k]; }
                            public int hashCode() { return keyUniverse[k].hashCode() ^ Objects.hashCode(vals[k]); }
                            public boolean equals(Object o) { return o instanceof Map.Entry<?, ?> e && keyUniverse[k].equals(e.getKey()) && Objects.equals(vals[k], e.getValue()); }
                        };
                    }
                    public void remove() { if (last < 0) throw new IllegalStateException(); has[last] = false; vals[last] = null; size--; last = -1; }
                };
            }
        };
    }
}
