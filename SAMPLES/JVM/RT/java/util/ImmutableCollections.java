package java.util;
class ImmutableCollections {
    static UnsupportedOperationException uoe() { return new UnsupportedOperationException(); }
    static abstract class ImmList<E> extends AbstractList<E> implements RandomAccess, java.io.Serializable {
        final Object[] a;
        ImmList(Object[] a) { this.a = a; }
        Object writeReplace() { return new CollSer(CollSer.IMM_LIST, a.clone()); }
        public int size() { return a.length; }
        public E get(int i) { if (i < 0 || i >= a.length) throw new IndexOutOfBoundsException("Index " + i + " out of bounds for length " + a.length); return (E) a[i]; }
        public boolean add(E e) { throw uoe(); }
        public void add(int i, E e) { throw uoe(); }
        public boolean addAll(Collection<? extends E> c) { throw uoe(); }
        public boolean addAll(int i, Collection<? extends E> c) { throw uoe(); }
        public void clear() { throw uoe(); }
        public boolean remove(Object o) { throw uoe(); }
        public E remove(int i) { throw uoe(); }
        public boolean removeAll(Collection<?> c) { throw uoe(); }
        public boolean removeIf(java.util.function.Predicate<? super E> f) { throw uoe(); }
        public boolean retainAll(Collection<?> c) { throw uoe(); }
        public void replaceAll(java.util.function.UnaryOperator<E> o) { throw uoe(); }
        public E set(int i, E e) { throw uoe(); }
        public void sort(Comparator<? super E> c) { throw uoe(); }
        public boolean contains(Object o) { Objects.requireNonNull(o); return indexOf(o) >= 0; }
        public List<E> subList(int from, int to) {
            if (from < 0 || to > a.length || from > to) throw new IndexOutOfBoundsException("fromIndex: " + from + ", toIndex: " + to);
            return new ListN<E>(Arrays.copyOfRange(a, from, to));
        }
    }
    static final class ListN<E> extends ImmList<E> {
    private static final long serialVersionUID = 3109894000706418650L; ListN(Object[] a) { super(a); } }
    static <E> List<E> listOf(Object... es) {
        for (Object e : es) Objects.requireNonNull(e);
        return new ListN<E>(es.clone());
    }
    static final class SetN<E> extends AbstractSet<E> implements java.io.Serializable {
    private static final long serialVersionUID = 7658445931194884555L;
        final LinkedHashSet<E> s = new LinkedHashSet<>();
        Object writeReplace() { return new CollSer(CollSer.IMM_SET, s.toArray()); }
        public int size() { return s.size(); }
        public Iterator<E> iterator() {
            final Iterator<E> it = s.iterator();
            return new Iterator<E>() { public boolean hasNext() { return it.hasNext(); } public E next() { return it.next(); } };
        }
        public boolean contains(Object o) { Objects.requireNonNull(o); return s.contains(o); }
        public boolean add(E e) { throw uoe(); }
        public boolean remove(Object o) { throw uoe(); }
        public boolean addAll(Collection<? extends E> c) { throw uoe(); }
        public boolean removeAll(Collection<?> c) { throw uoe(); }
        public boolean retainAll(Collection<?> c) { throw uoe(); }
        public boolean removeIf(java.util.function.Predicate<? super E> f) { throw uoe(); }
        public void clear() { throw uoe(); }
    }
    static <E> Set<E> setOf(Object... es) {
        SetN<E> r = new SetN<>();
        for (Object e : es) {
            Objects.requireNonNull(e);
            if (!r.s.add((E) e)) throw new IllegalArgumentException("duplicate element: " + e);
        }
        return r;
    }
    static final class MapN<K, V> extends AbstractMap<K, V> implements java.io.Serializable {
    private static final long serialVersionUID = 7621843055432902789L;
        final LinkedHashMap<K, V> m = new LinkedHashMap<>();
        Object writeReplace() {
            Object[] kv = new Object[m.size() * 2];
            int i = 0;
            for (Map.Entry<K, V> e : m.entrySet()) { kv[i++] = e.getKey(); kv[i++] = e.getValue(); }
            return new CollSer(CollSer.IMM_MAP, kv);
        }
        public int size() { return m.size(); }
        public V get(Object k) { Objects.requireNonNull(k); return m.get(k); }
        public boolean containsKey(Object k) { Objects.requireNonNull(k); return m.containsKey(k); }
        public V put(K k, V v) { throw uoe(); }
        public V remove(Object k) { throw uoe(); }
        public void clear() { throw uoe(); }
        public void putAll(Map<? extends K, ? extends V> x) { throw uoe(); }
        public V putIfAbsent(K k, V v) { throw uoe(); }
        public V merge(K k, V v, java.util.function.BiFunction<? super V, ? super V, ? extends V> f) { throw uoe(); }
        public V compute(K k, java.util.function.BiFunction<? super K, ? super V, ? extends V> f) { throw uoe(); }
        public V computeIfAbsent(K k, java.util.function.Function<? super K, ? extends V> f) { throw uoe(); }
        public Set<Map.Entry<K, V>> entrySet() {
            return new AbstractSet<Map.Entry<K, V>>() {
                public int size() { return m.size(); }
                public Iterator<Map.Entry<K, V>> iterator() {
                    final Iterator<Map.Entry<K, V>> it = m.entrySet().iterator();
                    return new Iterator<Map.Entry<K, V>>() {
                        public boolean hasNext() { return it.hasNext(); }
                        public Map.Entry<K, V> next() { Map.Entry<K, V> e = it.next(); return new AbstractMap.SimpleImmutableEntry<K, V>(e.getKey(), e.getValue()); }
                    };
                }
            };
        }
    }
    static <K, V> Map<K, V> mapOf(Object... kv) {
        MapN<K, V> r = new MapN<>();
        for (int i = 0; i < kv.length; i += 2) {
            Objects.requireNonNull(kv[i]); Objects.requireNonNull(kv[i + 1]);
            if (r.m.put((K) kv[i], (V) kv[i + 1]) != null) throw new IllegalArgumentException("duplicate key: " + kv[i]);
        }
        return r;
    }
}
