package java.util;
import java.util.function.*;
public class Collections {
    private Collections() {}
    public static final List EMPTY_LIST = ImmutableCollections.listOf();
    public static final Set EMPTY_SET = ImmutableCollections.setOf();
    public static final Map EMPTY_MAP = ImmutableCollections.mapOf();
    public static <T extends Comparable<? super T>> void sort(List<T> list) { list.sort(null); }
    public static <T> void sort(List<T> list, Comparator<? super T> c) { list.sort(c); }
    public static <T> int binarySearch(List<? extends Comparable<? super T>> list, T key) {
        int low = 0, high = list.size() - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            Comparable<? super T> midVal = list.get(mid);
            int cmp = midVal.compareTo(key);
            if (cmp < 0) low = mid + 1; else if (cmp > 0) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static <T> int binarySearch(List<? extends T> list, T key, Comparator<? super T> c) {
        if (c == null) return binarySearch((List<? extends Comparable<? super T>>) list, key);
        int low = 0, high = list.size() - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            T midVal = list.get(mid);
            int cmp = c.compare(midVal, key);
            if (cmp < 0) low = mid + 1; else if (cmp > 0) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static void reverse(List<?> list) {
        List<Object> l = (List<Object>) list;
        for (int i = 0, mid = l.size() >> 1, j = l.size() - 1; i < mid; i++, j--) l.set(i, l.set(j, l.get(i)));
    }
    public static void shuffle(List<?> list) { shuffle(list, new Random()); }
    public static void shuffle(List<?> list, Random rnd) {
        int size = list.size();
        List<Object> l = (List<Object>) list;
        for (int i = size; i > 1; i--) l.set(i - 1, l.set(rnd.nextInt(i), l.get(i - 1)));
    }
    public static void swap(List<?> list, int i, int j) {
        final List<Object> l = (List<Object>) list;
        l.set(i, l.set(j, l.get(i)));
    }
    public static <T> void fill(List<? super T> list, T obj) { for (int i = 0; i < list.size(); i++) list.set(i, obj); }
    public static <T> void copy(List<? super T> dest, List<? extends T> src) {
        if (src.size() > dest.size()) throw new IndexOutOfBoundsException("Source does not fit in dest");
        for (int i = 0; i < src.size(); i++) dest.set(i, src.get(i));
    }
    public static <T extends Object & Comparable<? super T>> T min(Collection<? extends T> coll) {
        Iterator<? extends T> i = coll.iterator();
        T candidate = i.next();
        while (i.hasNext()) { T next = i.next(); if (next.compareTo(candidate) < 0) candidate = next; }
        return candidate;
    }
    public static <T> T min(Collection<? extends T> coll, Comparator<? super T> comp) {
        if (comp == null) return (T) min((Collection) coll);
        Iterator<? extends T> i = coll.iterator();
        T candidate = i.next();
        while (i.hasNext()) { T next = i.next(); if (comp.compare(next, candidate) < 0) candidate = next; }
        return candidate;
    }
    public static <T extends Object & Comparable<? super T>> T max(Collection<? extends T> coll) {
        Iterator<? extends T> i = coll.iterator();
        T candidate = i.next();
        while (i.hasNext()) { T next = i.next(); if (next.compareTo(candidate) > 0) candidate = next; }
        return candidate;
    }
    public static <T> T max(Collection<? extends T> coll, Comparator<? super T> comp) {
        if (comp == null) return (T) max((Collection) coll);
        Iterator<? extends T> i = coll.iterator();
        T candidate = i.next();
        while (i.hasNext()) { T next = i.next(); if (comp.compare(next, candidate) > 0) candidate = next; }
        return candidate;
    }
    public static void rotate(List<?> list, int distance) {
        List<Object> l = (List<Object>) list;
        int size = l.size();
        if (size == 0) return;
        distance = distance % size;
        if (distance < 0) distance += size;
        if (distance == 0) return;
        Object[] a = l.toArray();
        for (int i = 0; i < size; i++) l.set((i + distance) % size, a[i]);
    }
    public static <T> boolean replaceAll(List<T> list, T oldVal, T newVal) {
        boolean result = false;
        for (int i = 0; i < list.size(); i++) if (Objects.equals(list.get(i), oldVal)) { list.set(i, newVal); result = true; }
        return result;
    }
    public static int indexOfSubList(List<?> source, List<?> target) {
        int n = source.size(), m = target.size();
        for (int i = 0; i + m <= n; i++) {
            boolean ok = true;
            for (int j = 0; j < m; j++) if (!Objects.equals(source.get(i + j), target.get(j))) { ok = false; break; }
            if (ok) return i;
        }
        return -1;
    }
    public static <T> Collection<T> unmodifiableCollection(Collection<? extends T> c) { return new UnmodColl<T>((Collection<T>) c); }
    public static <T> Set<T> unmodifiableSet(Set<? extends T> s) { return new UnmodSet<T>((Set<T>) s); }
    public static <T> SortedSet<T> unmodifiableSortedSet(SortedSet<T> s) { return s; }
    public static <T> List<T> unmodifiableList(List<? extends T> list) { return new UnmodList<T>((List<T>) list); }
    public static <K, V> Map<K, V> unmodifiableMap(Map<? extends K, ? extends V> m) { return new UnmodMap<K, V>((Map<K, V>) m); }
    public static <K, V> SortedMap<K, V> unmodifiableSortedMap(SortedMap<K, ? extends V> m) { return (SortedMap<K, V>) m; }
    static class UnmodColl<E> implements Collection<E>, java.io.Serializable {
        final Collection<E> c;
        UnmodColl(Collection<E> c) { if (c == null) throw new NullPointerException(); this.c = c; }
        public int size() { return c.size(); }
        public boolean isEmpty() { return c.isEmpty(); }
        public boolean contains(Object o) { return c.contains(o); }
        public Object[] toArray() { return c.toArray(); }
        public <T> T[] toArray(T[] a) { return c.toArray(a); }
        public String toString() { return c.toString(); }
        public Iterator<E> iterator() {
            return new Iterator<E>() {
                private final Iterator<? extends E> i = c.iterator();
                public boolean hasNext() { return i.hasNext(); }
                public E next() { return i.next(); }
                public void remove() { throw new UnsupportedOperationException(); }
            };
        }
        public boolean add(E e) { throw new UnsupportedOperationException(); }
        public boolean remove(Object o) { throw new UnsupportedOperationException(); }
        public boolean containsAll(Collection<?> coll) { return c.containsAll(coll); }
        public boolean addAll(Collection<? extends E> coll) { throw new UnsupportedOperationException(); }
        public boolean removeAll(Collection<?> coll) { throw new UnsupportedOperationException(); }
        public boolean retainAll(Collection<?> coll) { throw new UnsupportedOperationException(); }
        public void clear() { throw new UnsupportedOperationException(); }
        public void forEach(Consumer<? super E> action) { c.forEach(action); }
        public boolean removeIf(Predicate<? super E> filter) { throw new UnsupportedOperationException(); }
    }
    static class UnmodSet<E> extends UnmodColl<E> implements Set<E> {
        UnmodSet(Set<E> s) { super(s); }
        public boolean equals(Object o) { return o == this || c.equals(o); }
        public int hashCode() { return c.hashCode(); }
    }
    static class UnmodList<E> extends UnmodColl<E> implements List<E> {
        final List<E> list;
        UnmodList(List<E> list) { super(list); this.list = list; }
        public boolean equals(Object o) { return o == this || list.equals(o); }
        public int hashCode() { return list.hashCode(); }
        public E get(int index) { return list.get(index); }
        public E set(int index, E element) { throw new UnsupportedOperationException(); }
        public void add(int index, E element) { throw new UnsupportedOperationException(); }
        public E remove(int index) { throw new UnsupportedOperationException(); }
        public int indexOf(Object o) { return list.indexOf(o); }
        public int lastIndexOf(Object o) { return list.lastIndexOf(o); }
        public boolean addAll(int index, Collection<? extends E> c) { throw new UnsupportedOperationException(); }
        public void replaceAll(UnaryOperator<E> operator) { throw new UnsupportedOperationException(); }
        public void sort(Comparator<? super E> c) { throw new UnsupportedOperationException(); }
        public ListIterator<E> listIterator() { return listIterator(0); }
        public ListIterator<E> listIterator(final int index) {
            return new ListIterator<E>() {
                private final ListIterator<? extends E> i = list.listIterator(index);
                public boolean hasNext() { return i.hasNext(); }
                public E next() { return i.next(); }
                public boolean hasPrevious() { return i.hasPrevious(); }
                public E previous() { return i.previous(); }
                public int nextIndex() { return i.nextIndex(); }
                public int previousIndex() { return i.previousIndex(); }
                public void remove() { throw new UnsupportedOperationException(); }
                public void set(E e) { throw new UnsupportedOperationException(); }
                public void add(E e) { throw new UnsupportedOperationException(); }
            };
        }
        public List<E> subList(int fromIndex, int toIndex) { return new UnmodList<E>(list.subList(fromIndex, toIndex)); }
    }
    static class UnmodMap<K, V> implements Map<K, V>, java.io.Serializable {
        private final Map<K, V> m;
        UnmodMap(Map<K, V> m) { if (m == null) throw new NullPointerException(); this.m = m; }
        public int size() { return m.size(); }
        public boolean isEmpty() { return m.isEmpty(); }
        public boolean containsKey(Object key) { return m.containsKey(key); }
        public boolean containsValue(Object val) { return m.containsValue(val); }
        public V get(Object key) { return m.get(key); }
        public V put(K key, V value) { throw new UnsupportedOperationException(); }
        public V remove(Object key) { throw new UnsupportedOperationException(); }
        public void putAll(Map<? extends K, ? extends V> m) { throw new UnsupportedOperationException(); }
        public void clear() { throw new UnsupportedOperationException(); }
        public Set<K> keySet() { return unmodifiableSet(m.keySet()); }
        public Set<Map.Entry<K, V>> entrySet() {
            Set<Map.Entry<K, V>> src = m.entrySet();
            return new UnmodSet<Map.Entry<K, V>>(src) {
                public Iterator<Map.Entry<K, V>> iterator() {
                    final Iterator<Map.Entry<K, V>> i = c.iterator();
                    return new Iterator<Map.Entry<K, V>>() {
                        public boolean hasNext() { return i.hasNext(); }
                        public Map.Entry<K, V> next() { Map.Entry<K, V> e = i.next(); return new AbstractMap.SimpleImmutableEntry<K, V>(e.getKey(), e.getValue()); }
                    };
                }
            };
        }
        public Collection<V> values() { return unmodifiableCollection(m.values()); }
        public boolean equals(Object o) { return o == this || m.equals(o); }
        public int hashCode() { return m.hashCode(); }
        public String toString() { return m.toString(); }
        public V getOrDefault(Object k, V defaultValue) { return m.getOrDefault(k, defaultValue); }
        public void forEach(BiConsumer<? super K, ? super V> action) { m.forEach(action); }
        public V putIfAbsent(K key, V value) { throw new UnsupportedOperationException(); }
        public V computeIfAbsent(K key, Function<? super K, ? extends V> f) { throw new UnsupportedOperationException(); }
        public V merge(K key, V value, BiFunction<? super V, ? super V, ? extends V> f) { throw new UnsupportedOperationException(); }
        public V compute(K key, BiFunction<? super K, ? super V, ? extends V> f) { throw new UnsupportedOperationException(); }
    }
    public static <T> Collection<T> synchronizedCollection(Collection<T> c) { return c; }
    public static <T> Set<T> synchronizedSet(Set<T> s) { return s; }
    public static <T> List<T> synchronizedList(List<T> list) { return list; }
    public static <K, V> Map<K, V> synchronizedMap(Map<K, V> m) { return m; }
    public static <T> Iterator<T> emptyIterator() { return (Iterator<T>) EMPTY_LIST.iterator(); }
    public static final <T> List<T> emptyList() { return (List<T>) EMPTY_LIST; }
    public static final <T> Set<T> emptySet() { return (Set<T>) EMPTY_SET; }
    public static final <K, V> Map<K, V> emptyMap() { return (Map<K, V>) EMPTY_MAP; }
    public static <T> Set<T> singleton(T o) { Set<T> s = new HashSet<>(); s.add(o); return unmodifiableSet(s); }
    public static <T> List<T> singletonList(T o) { return unmodifiableList(new ArrayList<>(Arrays.asList(o))); }
    public static <K, V> Map<K, V> singletonMap(K key, V value) { Map<K, V> m = new HashMap<>(); m.put(key, value); return unmodifiableMap(m); }
    public static <T> List<T> nCopies(int n, T o) {
        if (n < 0) throw new IllegalArgumentException("List length = " + n);
        ArrayList<T> l = new ArrayList<>(n);
        for (int i = 0; i < n; i++) l.add(o);
        return unmodifiableList(l);
    }
    static final class NaturalOrder implements Comparator<Comparable<Object>> {
        static final NaturalOrder INSTANCE = new NaturalOrder();
        public int compare(Comparable<Object> c1, Comparable<Object> c2) { return c1.compareTo(c2); }
        public Comparator<Comparable<Object>> reversed() { return (Comparator<Comparable<Object>>) (Comparator) REVERSE; }
    }
    static final Comparator<Object> REVERSE = (a, b) -> ((Comparable<Object>) b).compareTo(a);
    public static <T> Comparator<T> reverseOrder() { return (Comparator<T>) REVERSE; }
    public static <T> Comparator<T> reverseOrder(Comparator<T> cmp) {
        if (cmp == null) return (Comparator<T>) REVERSE;
        if (cmp == REVERSE) return (Comparator<T>) NaturalOrder.INSTANCE;
        return (a, b) -> cmp.compare(b, a);
    }
    public static <T> Enumeration<T> enumeration(final Collection<T> c) {
        return new Enumeration<T>() {
            private final Iterator<T> i = c.iterator();
            public boolean hasMoreElements() { return i.hasNext(); }
            public T nextElement() { return i.next(); }
        };
    }
    public static <T> ArrayList<T> list(Enumeration<T> e) { ArrayList<T> l = new ArrayList<>(); while (e.hasMoreElements()) l.add(e.nextElement()); return l; }
    public static int frequency(Collection<?> c, Object o) {
        int result = 0;
        if (o == null) { for (Object e : c) if (e == null) result++; }
        else { for (Object e : c) if (o.equals(e)) result++; }
        return result;
    }
    public static boolean disjoint(Collection<?> c1, Collection<?> c2) {
        for (Object e : c1) if (c2.contains(e)) return false;
        return true;
    }
    public static <T> boolean addAll(Collection<? super T> c, T... elements) {
        boolean result = false;
        for (T element : elements) result |= c.add(element);
        return result;
    }
    public static <E> Set<E> newSetFromMap(Map<E, Boolean> map) { return new HashSet<E>(); }
    public static <T> Queue<T> asLifoQueue(Deque<T> deque) { return deque; }
}
