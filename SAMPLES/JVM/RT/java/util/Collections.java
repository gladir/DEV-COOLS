package java.util;
import java.util.function.*;
public class Collections {
    private Collections() {}
    public static final List EMPTY_LIST = new EmptyList<>();
    public static final Set EMPTY_SET = new EmptySet<>();
    public static final Map EMPTY_MAP = new EmptyMap<>();
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

    // ----- vues non modifiables ------------------------------------------------
    public static <T> Collection<T> unmodifiableCollection(Collection<? extends T> c) {
        if (c.getClass() == UnmodifiableCollection.class) return (Collection<T>) c;
        return new UnmodifiableCollection<>(c);
    }
    public static <T> Set<T> unmodifiableSet(Set<? extends T> s) {
        if (s.getClass() == UnmodifiableSet.class) return (Set<T>) s;
        return new UnmodifiableSet<>(s);
    }
    public static <T> SortedSet<T> unmodifiableSortedSet(SortedSet<T> s) {
        if (s.getClass() == UnmodifiableSortedSet.class) return s;
        return new UnmodifiableSortedSet<>(s);
    }
    public static <T> NavigableSet<T> unmodifiableNavigableSet(NavigableSet<T> s) {
        if (s.getClass() == UnmodifiableNavigableSet.class) return s;
        return new UnmodifiableNavigableSet<>(s);
    }
    public static <T> List<T> unmodifiableList(List<? extends T> list) {
        if (list.getClass() == UnmodifiableList.class || list.getClass() == UnmodifiableRandomAccessList.class) return (List<T>) list;
        return (list instanceof RandomAccess ? new UnmodifiableRandomAccessList<>(list) : new UnmodifiableList<>(list));
    }
    public static <K, V> Map<K, V> unmodifiableMap(Map<? extends K, ? extends V> m) {
        if (m.getClass() == UnmodifiableMap.class) return (Map<K, V>) m;
        return new UnmodifiableMap<>(m);
    }
    public static <K, V> SortedMap<K, V> unmodifiableSortedMap(SortedMap<K, ? extends V> m) {
        if (m.getClass() == UnmodifiableSortedMap.class) return (SortedMap<K, V>) m;
        return new UnmodifiableSortedMap<>(m);
    }
    public static <K, V> NavigableMap<K, V> unmodifiableNavigableMap(NavigableMap<K, ? extends V> m) {
        if (m.getClass() == UnmodifiableNavigableMap.class) return (NavigableMap<K, V>) m;
        return new UnmodifiableNavigableMap<>(m);
    }
    static class UnmodifiableCollection<E> implements Collection<E>, java.io.Serializable {
    private static final long serialVersionUID = 1820017752578914078L;
        final Collection<? extends E> c;
        UnmodifiableCollection(Collection<? extends E> c) { if (c == null) throw new NullPointerException(); this.c = c; }
        public int size() { return c.size(); }
        public boolean isEmpty() { return c.isEmpty(); }
        public boolean contains(Object o) { return c.contains(o); }
        public Object[] toArray() { return c.toArray(); }
        public <T> T[] toArray(T[] a) { return c.toArray(a); }
        public <T> T[] toArray(IntFunction<T[]> f) { return c.toArray(f); }
        public String toString() { return c.toString(); }
        public Iterator<E> iterator() {
            return new Iterator<E>() {
                private final Iterator<? extends E> i = c.iterator();
                public boolean hasNext() { return i.hasNext(); }
                public E next() { return i.next(); }
                public void remove() { throw new UnsupportedOperationException(); }
                public void forEachRemaining(Consumer<? super E> action) { i.forEachRemaining(action); }
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
        public java.util.stream.Stream<E> stream() { return (java.util.stream.Stream<E>) c.stream(); }
    }
    static class UnmodifiableSet<E> extends UnmodifiableCollection<E> implements Set<E>, java.io.Serializable {
    private static final long serialVersionUID = -9215047833775013803L;
        UnmodifiableSet(Set<? extends E> s) { super(s); }
        public boolean equals(Object o) { return o == this || c.equals(o); }
        public int hashCode() { return c.hashCode(); }
    }
    static class UnmodifiableSortedSet<E> extends UnmodifiableSet<E> implements SortedSet<E>, java.io.Serializable {
    private static final long serialVersionUID = -4929149591599911165L;
        private final SortedSet<E> ss;
        UnmodifiableSortedSet(SortedSet<E> s) { super(s); ss = s; }
        public Comparator<? super E> comparator() { return ss.comparator(); }
        public SortedSet<E> subSet(E fromElement, E toElement) { return new UnmodifiableSortedSet<>(ss.subSet(fromElement, toElement)); }
        public SortedSet<E> headSet(E toElement) { return new UnmodifiableSortedSet<>(ss.headSet(toElement)); }
        public SortedSet<E> tailSet(E fromElement) { return new UnmodifiableSortedSet<>(ss.tailSet(fromElement)); }
        public E first() { return ss.first(); }
        public E last() { return ss.last(); }
    }
    static class UnmodifiableNavigableSet<E> extends UnmodifiableSortedSet<E> implements NavigableSet<E>, java.io.Serializable {
    private static final long serialVersionUID = -6027448201786391929L;
        private final NavigableSet<E> ns;
        UnmodifiableNavigableSet(NavigableSet<E> s) { super(s); ns = s; }
        public E lower(E e) { return ns.lower(e); }
        public E floor(E e) { return ns.floor(e); }
        public E ceiling(E e) { return ns.ceiling(e); }
        public E higher(E e) { return ns.higher(e); }
        public E pollFirst() { throw new UnsupportedOperationException(); }
        public E pollLast() { throw new UnsupportedOperationException(); }
        public NavigableSet<E> descendingSet() { return new UnmodifiableNavigableSet<>(ns.descendingSet()); }
        public Iterator<E> descendingIterator() { return descendingSet().iterator(); }
        public NavigableSet<E> subSet(E fromElement, boolean fromInclusive, E toElement, boolean toInclusive) {
            return new UnmodifiableNavigableSet<>(ns.subSet(fromElement, fromInclusive, toElement, toInclusive));
        }
        public NavigableSet<E> headSet(E toElement, boolean inclusive) { return new UnmodifiableNavigableSet<>(ns.headSet(toElement, inclusive)); }
        public NavigableSet<E> tailSet(E fromElement, boolean inclusive) { return new UnmodifiableNavigableSet<>(ns.tailSet(fromElement, inclusive)); }
    }
    static class UnmodifiableList<E> extends UnmodifiableCollection<E> implements List<E> {
        private static final long serialVersionUID = -283967356065247728L;
        final List<? extends E> list;
        UnmodifiableList(List<? extends E> list) { super(list); this.list = list; }
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
                public void forEachRemaining(Consumer<? super E> action) { i.forEachRemaining(action); }
            };
        }
        public List<E> subList(int fromIndex, int toIndex) { return new UnmodifiableList<>(list.subList(fromIndex, toIndex)); }
        private Object readResolve() { return (list instanceof RandomAccess ? new UnmodifiableRandomAccessList<>(list) : this); }
    }
    static class UnmodifiableRandomAccessList<E> extends UnmodifiableList<E> implements RandomAccess {
        private static final long serialVersionUID = -2542308836966382001L;
        UnmodifiableRandomAccessList(List<? extends E> list) { super(list); }
        public List<E> subList(int fromIndex, int toIndex) { return new UnmodifiableRandomAccessList<>(list.subList(fromIndex, toIndex)); }
        private Object writeReplace() { return new UnmodifiableList<>(list); }
    }
    private static class UnmodifiableEntry<K, V> implements Map.Entry<K, V> {
        private Map.Entry<? extends K, ? extends V> e;
        UnmodifiableEntry(Map.Entry<? extends K, ? extends V> e) { this.e = Objects.requireNonNull(e); }
        public K getKey() { return e.getKey(); }
        public V getValue() { return e.getValue(); }
        public V setValue(V value) { throw new UnsupportedOperationException(); }
        public int hashCode() { return e.hashCode(); }
        public boolean equals(Object o) {
            if (this == o) return true;
            return o instanceof Map.Entry<?, ?> t && Objects.equals(e.getKey(), t.getKey()) && Objects.equals(e.getValue(), t.getValue());
        }
        public String toString() { return e.toString(); }
    }
    static class UnmodifiableEntrySet<K, V> extends UnmodifiableSet<Map.Entry<K, V>> {
        UnmodifiableEntrySet(Set<? extends Map.Entry<? extends K, ? extends V>> s) { super((Set) s); }
        public Iterator<Map.Entry<K, V>> iterator() {
            return new Iterator<Map.Entry<K, V>>() {
                private final Iterator<? extends Map.Entry<? extends K, ? extends V>> i = c.iterator();
                public boolean hasNext() { return i.hasNext(); }
                public Map.Entry<K, V> next() { return new UnmodifiableEntry<>(i.next()); }
                public void remove() { throw new UnsupportedOperationException(); }
            };
        }
        public Object[] toArray() {
            Object[] a = c.toArray();
            for (int i = 0; i < a.length; i++) a[i] = new UnmodifiableEntry<>((Map.Entry<? extends K, ? extends V>) a[i]);
            return a;
        }
        public <T> T[] toArray(T[] a) {
            Object[] arr = c.toArray(a.length == 0 ? a : Arrays.copyOf(a, 0));
            for (int i = 0; i < arr.length; i++) arr[i] = new UnmodifiableEntry<>((Map.Entry<? extends K, ? extends V>) arr[i]);
            if (arr.length > a.length) return (T[]) arr;
            System.arraycopy(arr, 0, a, 0, arr.length);
            if (a.length > arr.length) a[arr.length] = null;
            return a;
        }
        public boolean contains(Object o) {
            if (!(o instanceof Map.Entry)) return false;
            return c.contains(new UnmodifiableEntry<>((Map.Entry<?, ?>) o));
        }
        public boolean equals(Object o) {
            if (o == this) return true;
            return o instanceof Set<?> s && s.size() == c.size() && containsAll(s);
        }
    }
    private static class UnmodifiableMap<K, V> implements Map<K, V>, java.io.Serializable {
    private static final long serialVersionUID = -1034234728574286014L;
        private final Map<? extends K, ? extends V> m;
        UnmodifiableMap(Map<? extends K, ? extends V> m) { if (m == null) throw new NullPointerException(); this.m = m; }
        public int size() { return m.size(); }
        public boolean isEmpty() { return m.isEmpty(); }
        public boolean containsKey(Object key) { return m.containsKey(key); }
        public boolean containsValue(Object val) { return m.containsValue(val); }
        public V get(Object key) { return m.get(key); }
        public V put(K key, V value) { throw new UnsupportedOperationException(); }
        public V remove(Object key) { throw new UnsupportedOperationException(); }
        public void putAll(Map<? extends K, ? extends V> m) { throw new UnsupportedOperationException(); }
        public void clear() { throw new UnsupportedOperationException(); }
        private transient Set<K> keySet;
        private transient Set<Map.Entry<K, V>> entrySet;
        private transient Collection<V> values;
        public Set<K> keySet() { if (keySet == null) keySet = unmodifiableSet(m.keySet()); return keySet; }
        public Set<Map.Entry<K, V>> entrySet() { if (entrySet == null) entrySet = new UnmodifiableEntrySet<>(m.entrySet()); return entrySet; }
        public Collection<V> values() { if (values == null) values = unmodifiableCollection(m.values()); return values; }
        public boolean equals(Object o) { return o == this || m.equals(o); }
        public int hashCode() { return m.hashCode(); }
        public String toString() { return m.toString(); }
        public V getOrDefault(Object k, V defaultValue) { return ((Map<K, V>) m).getOrDefault(k, defaultValue); }
        public void forEach(BiConsumer<? super K, ? super V> action) { ((Map<K, V>) m).forEach(action); }
        public void replaceAll(BiFunction<? super K, ? super V, ? extends V> function) { throw new UnsupportedOperationException(); }
        public V putIfAbsent(K key, V value) { throw new UnsupportedOperationException(); }
        public boolean remove(Object key, Object value) { throw new UnsupportedOperationException(); }
        public boolean replace(K key, V oldValue, V newValue) { throw new UnsupportedOperationException(); }
        public V replace(K key, V value) { throw new UnsupportedOperationException(); }
        public V computeIfAbsent(K key, Function<? super K, ? extends V> mappingFunction) { throw new UnsupportedOperationException(); }
        public V computeIfPresent(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        public V compute(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        public V merge(K key, V value, BiFunction<? super V, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
    }
    static class UnmodifiableSortedMap<K, V> extends UnmodifiableMap<K, V> implements SortedMap<K, V>, java.io.Serializable {
    private static final long serialVersionUID = -8806743815996713206L;
        private final SortedMap<K, ? extends V> sm;
        UnmodifiableSortedMap(SortedMap<K, ? extends V> m) { super(m); sm = m; }
        public Comparator<? super K> comparator() { return sm.comparator(); }
        public SortedMap<K, V> subMap(K fromKey, K toKey) { return new UnmodifiableSortedMap<>(sm.subMap(fromKey, toKey)); }
        public SortedMap<K, V> headMap(K toKey) { return new UnmodifiableSortedMap<>(sm.headMap(toKey)); }
        public SortedMap<K, V> tailMap(K fromKey) { return new UnmodifiableSortedMap<>(sm.tailMap(fromKey)); }
        public K firstKey() { return sm.firstKey(); }
        public K lastKey() { return sm.lastKey(); }
    }
    static class UnmodifiableNavigableMap<K, V> extends UnmodifiableSortedMap<K, V> implements NavigableMap<K, V>, java.io.Serializable {
    private static final long serialVersionUID = -4858195264774772197L;
        private final NavigableMap<K, ? extends V> nm;
        UnmodifiableNavigableMap(NavigableMap<K, ? extends V> m) { super(m); nm = m; }
        private Map.Entry<K, V> ue(Map.Entry<K, ? extends V> e) { return e == null ? null : new AbstractMap.SimpleImmutableEntry<K, V>(e.getKey(), e.getValue()); }
        public K lowerKey(K key) { return nm.lowerKey(key); }
        public K floorKey(K key) { return nm.floorKey(key); }
        public K ceilingKey(K key) { return nm.ceilingKey(key); }
        public K higherKey(K key) { return nm.higherKey(key); }
        public Map.Entry<K, V> lowerEntry(K key) { return ue(nm.lowerEntry(key)); }
        public Map.Entry<K, V> floorEntry(K key) { return ue(nm.floorEntry(key)); }
        public Map.Entry<K, V> ceilingEntry(K key) { return ue(nm.ceilingEntry(key)); }
        public Map.Entry<K, V> higherEntry(K key) { return ue(nm.higherEntry(key)); }
        public Map.Entry<K, V> firstEntry() { return ue(nm.firstEntry()); }
        public Map.Entry<K, V> lastEntry() { return ue(nm.lastEntry()); }
        public Map.Entry<K, V> pollFirstEntry() { throw new UnsupportedOperationException(); }
        public Map.Entry<K, V> pollLastEntry() { throw new UnsupportedOperationException(); }
        public NavigableMap<K, V> descendingMap() { return unmodifiableNavigableMap(nm.descendingMap()); }
        public NavigableSet<K> navigableKeySet() { return unmodifiableNavigableSet(nm.navigableKeySet()); }
        public NavigableSet<K> descendingKeySet() { return unmodifiableNavigableSet(nm.descendingKeySet()); }
        public NavigableMap<K, V> subMap(K fromKey, boolean fromInclusive, K toKey, boolean toInclusive) {
            return unmodifiableNavigableMap(nm.subMap(fromKey, fromInclusive, toKey, toInclusive));
        }
        public NavigableMap<K, V> headMap(K toKey, boolean inclusive) { return unmodifiableNavigableMap(nm.headMap(toKey, inclusive)); }
        public NavigableMap<K, V> tailMap(K fromKey, boolean inclusive) { return unmodifiableNavigableMap(nm.tailMap(fromKey, inclusive)); }
    }

    // ----- vues synchronisees --------------------------------------------------
    public static <T> Collection<T> synchronizedCollection(Collection<T> c) { return new SynchronizedCollection<>(c); }
    public static <T> Set<T> synchronizedSet(Set<T> s) { return new SynchronizedSet<>(s); }
    public static <T> SortedSet<T> synchronizedSortedSet(SortedSet<T> s) { return new SynchronizedSortedSet<>(s); }
    public static <T> NavigableSet<T> synchronizedNavigableSet(NavigableSet<T> s) { return new SynchronizedNavigableSet<>(s); }
    public static <T> List<T> synchronizedList(List<T> list) {
        return (list instanceof RandomAccess ? new SynchronizedRandomAccessList<>(list) : new SynchronizedList<>(list));
    }
    public static <K, V> Map<K, V> synchronizedMap(Map<K, V> m) { return new SynchronizedMap<>(m); }
    public static <K, V> SortedMap<K, V> synchronizedSortedMap(SortedMap<K, V> m) { return new SynchronizedSortedMap<>(m); }
    public static <K, V> NavigableMap<K, V> synchronizedNavigableMap(NavigableMap<K, V> m) { return new SynchronizedNavigableMap<>(m); }
    static class SynchronizedCollection<E> implements Collection<E>, java.io.Serializable {
    private static final long serialVersionUID = 3053995032091335093L;
        final Collection<E> c;
        final Object mutex;
        SynchronizedCollection(Collection<E> c) { this.c = Objects.requireNonNull(c); mutex = this; }
        SynchronizedCollection(Collection<E> c, Object mutex) { this.c = Objects.requireNonNull(c); this.mutex = Objects.requireNonNull(mutex); }
        public int size() { synchronized (mutex) { return c.size(); } }
        public boolean isEmpty() { synchronized (mutex) { return c.isEmpty(); } }
        public boolean contains(Object o) { synchronized (mutex) { return c.contains(o); } }
        public Object[] toArray() { synchronized (mutex) { return c.toArray(); } }
        public <T> T[] toArray(T[] a) { synchronized (mutex) { return c.toArray(a); } }
        public <T> T[] toArray(IntFunction<T[]> f) { synchronized (mutex) { return c.toArray(f); } }
        public Iterator<E> iterator() { return c.iterator(); }
        public boolean add(E e) { synchronized (mutex) { return c.add(e); } }
        public boolean remove(Object o) { synchronized (mutex) { return c.remove(o); } }
        public boolean containsAll(Collection<?> coll) { synchronized (mutex) { return c.containsAll(coll); } }
        public boolean addAll(Collection<? extends E> coll) { synchronized (mutex) { return c.addAll(coll); } }
        public boolean removeAll(Collection<?> coll) { synchronized (mutex) { return c.removeAll(coll); } }
        public boolean retainAll(Collection<?> coll) { synchronized (mutex) { return c.retainAll(coll); } }
        public void clear() { synchronized (mutex) { c.clear(); } }
        public String toString() { synchronized (mutex) { return c.toString(); } }
        public void forEach(Consumer<? super E> consumer) { synchronized (mutex) { c.forEach(consumer); } }
        public boolean removeIf(Predicate<? super E> filter) { synchronized (mutex) { return c.removeIf(filter); } }
        public java.util.stream.Stream<E> stream() { return c.stream(); }
        private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException { synchronized (mutex) { s.defaultWriteObject(); } }
    }
    static class SynchronizedSet<E> extends SynchronizedCollection<E> implements Set<E> {
    private static final long serialVersionUID = 487447009682186044L;
        SynchronizedSet(Set<E> s) { super(s); }
        SynchronizedSet(Set<E> s, Object mutex) { super(s, mutex); }
        public boolean equals(Object o) { if (this == o) return true; synchronized (mutex) { return c.equals(o); } }
        public int hashCode() { synchronized (mutex) { return c.hashCode(); } }
    }
    static class SynchronizedSortedSet<E> extends SynchronizedSet<E> implements SortedSet<E> {
    private static final long serialVersionUID = 8695801310862127406L;
        private final SortedSet<E> ss;
        SynchronizedSortedSet(SortedSet<E> s) { super(s); ss = s; }
        SynchronizedSortedSet(SortedSet<E> s, Object mutex) { super(s, mutex); ss = s; }
        public Comparator<? super E> comparator() { synchronized (mutex) { return ss.comparator(); } }
        public SortedSet<E> subSet(E fromElement, E toElement) { synchronized (mutex) { return new SynchronizedSortedSet<>(ss.subSet(fromElement, toElement), mutex); } }
        public SortedSet<E> headSet(E toElement) { synchronized (mutex) { return new SynchronizedSortedSet<>(ss.headSet(toElement), mutex); } }
        public SortedSet<E> tailSet(E fromElement) { synchronized (mutex) { return new SynchronizedSortedSet<>(ss.tailSet(fromElement), mutex); } }
        public E first() { synchronized (mutex) { return ss.first(); } }
        public E last() { synchronized (mutex) { return ss.last(); } }
    }
    static class SynchronizedNavigableSet<E> extends SynchronizedSortedSet<E> implements NavigableSet<E> {
    private static final long serialVersionUID = -5505529816273629798L;
        private final NavigableSet<E> ns;
        SynchronizedNavigableSet(NavigableSet<E> s) { super(s); ns = s; }
        SynchronizedNavigableSet(NavigableSet<E> s, Object mutex) { super(s, mutex); ns = s; }
        public E lower(E e) { synchronized (mutex) { return ns.lower(e); } }
        public E floor(E e) { synchronized (mutex) { return ns.floor(e); } }
        public E ceiling(E e) { synchronized (mutex) { return ns.ceiling(e); } }
        public E higher(E e) { synchronized (mutex) { return ns.higher(e); } }
        public E pollFirst() { synchronized (mutex) { return ns.pollFirst(); } }
        public E pollLast() { synchronized (mutex) { return ns.pollLast(); } }
        public NavigableSet<E> descendingSet() { synchronized (mutex) { return new SynchronizedNavigableSet<>(ns.descendingSet(), mutex); } }
        public Iterator<E> descendingIterator() { synchronized (mutex) { return descendingSet().iterator(); } }
        public NavigableSet<E> subSet(E fromElement, boolean fromInclusive, E toElement, boolean toInclusive) {
            synchronized (mutex) { return new SynchronizedNavigableSet<>(ns.subSet(fromElement, fromInclusive, toElement, toInclusive), mutex); }
        }
        public NavigableSet<E> headSet(E toElement, boolean inclusive) { synchronized (mutex) { return new SynchronizedNavigableSet<>(ns.headSet(toElement, inclusive), mutex); } }
        public NavigableSet<E> tailSet(E fromElement, boolean inclusive) { synchronized (mutex) { return new SynchronizedNavigableSet<>(ns.tailSet(fromElement, inclusive), mutex); } }
    }
    static class SynchronizedList<E> extends SynchronizedCollection<E> implements List<E> {
    private static final long serialVersionUID = -7754090372962971524L;
        final List<E> list;
        SynchronizedList(List<E> list) { super(list); this.list = list; }
        SynchronizedList(List<E> list, Object mutex) { super(list, mutex); this.list = list; }
        public boolean equals(Object o) { if (this == o) return true; synchronized (mutex) { return list.equals(o); } }
        public int hashCode() { synchronized (mutex) { return list.hashCode(); } }
        public E get(int index) { synchronized (mutex) { return list.get(index); } }
        public E set(int index, E element) { synchronized (mutex) { return list.set(index, element); } }
        public void add(int index, E element) { synchronized (mutex) { list.add(index, element); } }
        public E remove(int index) { synchronized (mutex) { return list.remove(index); } }
        public int indexOf(Object o) { synchronized (mutex) { return list.indexOf(o); } }
        public int lastIndexOf(Object o) { synchronized (mutex) { return list.lastIndexOf(o); } }
        public boolean addAll(int index, Collection<? extends E> c) { synchronized (mutex) { return list.addAll(index, c); } }
        public ListIterator<E> listIterator() { return list.listIterator(); }
        public ListIterator<E> listIterator(int index) { return list.listIterator(index); }
        public List<E> subList(int fromIndex, int toIndex) { synchronized (mutex) { return new SynchronizedList<>(list.subList(fromIndex, toIndex), mutex); } }
        public void replaceAll(UnaryOperator<E> operator) { synchronized (mutex) { list.replaceAll(operator); } }
        public void sort(Comparator<? super E> c) { synchronized (mutex) { list.sort(c); } }
        private Object readResolve() { return (list instanceof RandomAccess ? new SynchronizedRandomAccessList<>(list) : this); }
    }
    static class SynchronizedRandomAccessList<E> extends SynchronizedList<E> implements RandomAccess {
    private static final long serialVersionUID = 1530674583602358482L;
        SynchronizedRandomAccessList(List<E> list) { super(list); }
        SynchronizedRandomAccessList(List<E> list, Object mutex) { super(list, mutex); }
        public List<E> subList(int fromIndex, int toIndex) { synchronized (mutex) { return new SynchronizedRandomAccessList<>(list.subList(fromIndex, toIndex), mutex); } }
        private Object writeReplace() { return new SynchronizedList<>(list); }
    }
    private static class SynchronizedMap<K, V> implements Map<K, V>, java.io.Serializable {
    private static final long serialVersionUID = 1978198479659022715L;
        private final Map<K, V> m;
        final Object mutex;
        SynchronizedMap(Map<K, V> m) { this.m = Objects.requireNonNull(m); mutex = this; }
        SynchronizedMap(Map<K, V> m, Object mutex) { this.m = m; this.mutex = mutex; }
        public int size() { synchronized (mutex) { return m.size(); } }
        public boolean isEmpty() { synchronized (mutex) { return m.isEmpty(); } }
        public boolean containsKey(Object key) { synchronized (mutex) { return m.containsKey(key); } }
        public boolean containsValue(Object value) { synchronized (mutex) { return m.containsValue(value); } }
        public V get(Object key) { synchronized (mutex) { return m.get(key); } }
        public V put(K key, V value) { synchronized (mutex) { return m.put(key, value); } }
        public V remove(Object key) { synchronized (mutex) { return m.remove(key); } }
        public void putAll(Map<? extends K, ? extends V> map) { synchronized (mutex) { m.putAll(map); } }
        public void clear() { synchronized (mutex) { m.clear(); } }
        private transient Set<K> keySet;
        private transient Set<Map.Entry<K, V>> entrySet;
        private transient Collection<V> values;
        public Set<K> keySet() { synchronized (mutex) { if (keySet == null) keySet = new SynchronizedSet<>(m.keySet(), mutex); return keySet; } }
        public Set<Map.Entry<K, V>> entrySet() { synchronized (mutex) { if (entrySet == null) entrySet = new SynchronizedSet<>(m.entrySet(), mutex); return entrySet; } }
        public Collection<V> values() { synchronized (mutex) { if (values == null) values = new SynchronizedCollection<>(m.values(), mutex); return values; } }
        public boolean equals(Object o) { if (this == o) return true; synchronized (mutex) { return m.equals(o); } }
        public int hashCode() { synchronized (mutex) { return m.hashCode(); } }
        public String toString() { synchronized (mutex) { return m.toString(); } }
        public V getOrDefault(Object k, V defaultValue) { synchronized (mutex) { return m.getOrDefault(k, defaultValue); } }
        public void forEach(BiConsumer<? super K, ? super V> action) { synchronized (mutex) { m.forEach(action); } }
        public void replaceAll(BiFunction<? super K, ? super V, ? extends V> function) { synchronized (mutex) { m.replaceAll(function); } }
        public V putIfAbsent(K key, V value) { synchronized (mutex) { return m.putIfAbsent(key, value); } }
        public boolean remove(Object key, Object value) { synchronized (mutex) { return m.remove(key, value); } }
        public boolean replace(K key, V oldValue, V newValue) { synchronized (mutex) { return m.replace(key, oldValue, newValue); } }
        public V replace(K key, V value) { synchronized (mutex) { return m.replace(key, value); } }
        public V computeIfAbsent(K key, Function<? super K, ? extends V> mappingFunction) { synchronized (mutex) { return m.computeIfAbsent(key, mappingFunction); } }
        public V computeIfPresent(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { synchronized (mutex) { return m.computeIfPresent(key, remappingFunction); } }
        public V compute(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { synchronized (mutex) { return m.compute(key, remappingFunction); } }
        public V merge(K key, V value, BiFunction<? super V, ? super V, ? extends V> remappingFunction) { synchronized (mutex) { return m.merge(key, value, remappingFunction); } }
        private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException { synchronized (mutex) { s.defaultWriteObject(); } }
    }
    static class SynchronizedSortedMap<K, V> extends SynchronizedMap<K, V> implements SortedMap<K, V> {
    private static final long serialVersionUID = -8798146769416483793L;
        private final SortedMap<K, V> sm;
        SynchronizedSortedMap(SortedMap<K, V> m) { super(m); sm = m; }
        SynchronizedSortedMap(SortedMap<K, V> m, Object mutex) { super(m, mutex); sm = m; }
        public Comparator<? super K> comparator() { synchronized (mutex) { return sm.comparator(); } }
        public SortedMap<K, V> subMap(K fromKey, K toKey) { synchronized (mutex) { return new SynchronizedSortedMap<>(sm.subMap(fromKey, toKey), mutex); } }
        public SortedMap<K, V> headMap(K toKey) { synchronized (mutex) { return new SynchronizedSortedMap<>(sm.headMap(toKey), mutex); } }
        public SortedMap<K, V> tailMap(K fromKey) { synchronized (mutex) { return new SynchronizedSortedMap<>(sm.tailMap(fromKey), mutex); } }
        public K firstKey() { synchronized (mutex) { return sm.firstKey(); } }
        public K lastKey() { synchronized (mutex) { return sm.lastKey(); } }
    }
    static class SynchronizedNavigableMap<K, V> extends SynchronizedSortedMap<K, V> implements NavigableMap<K, V> {
    private static final long serialVersionUID = 699392247599746807L;
        private final NavigableMap<K, V> nm;
        SynchronizedNavigableMap(NavigableMap<K, V> m) { super(m); nm = m; }
        SynchronizedNavigableMap(NavigableMap<K, V> m, Object mutex) { super(m, mutex); nm = m; }
        public Map.Entry<K, V> lowerEntry(K key) { synchronized (mutex) { return nm.lowerEntry(key); } }
        public K lowerKey(K key) { synchronized (mutex) { return nm.lowerKey(key); } }
        public Map.Entry<K, V> floorEntry(K key) { synchronized (mutex) { return nm.floorEntry(key); } }
        public K floorKey(K key) { synchronized (mutex) { return nm.floorKey(key); } }
        public Map.Entry<K, V> ceilingEntry(K key) { synchronized (mutex) { return nm.ceilingEntry(key); } }
        public K ceilingKey(K key) { synchronized (mutex) { return nm.ceilingKey(key); } }
        public Map.Entry<K, V> higherEntry(K key) { synchronized (mutex) { return nm.higherEntry(key); } }
        public K higherKey(K key) { synchronized (mutex) { return nm.higherKey(key); } }
        public Map.Entry<K, V> firstEntry() { synchronized (mutex) { return nm.firstEntry(); } }
        public Map.Entry<K, V> lastEntry() { synchronized (mutex) { return nm.lastEntry(); } }
        public Map.Entry<K, V> pollFirstEntry() { synchronized (mutex) { return nm.pollFirstEntry(); } }
        public Map.Entry<K, V> pollLastEntry() { synchronized (mutex) { return nm.pollLastEntry(); } }
        public NavigableMap<K, V> descendingMap() { synchronized (mutex) { return new SynchronizedNavigableMap<>(nm.descendingMap(), mutex); } }
        public NavigableSet<K> navigableKeySet() { synchronized (mutex) { return new SynchronizedNavigableSet<>(nm.navigableKeySet(), mutex); } }
        public NavigableSet<K> descendingKeySet() { synchronized (mutex) { return new SynchronizedNavigableSet<>(nm.descendingKeySet(), mutex); } }
        public NavigableMap<K, V> subMap(K fromKey, boolean fromInclusive, K toKey, boolean toInclusive) {
            synchronized (mutex) { return new SynchronizedNavigableMap<>(nm.subMap(fromKey, fromInclusive, toKey, toInclusive), mutex); }
        }
        public NavigableMap<K, V> headMap(K toKey, boolean inclusive) { synchronized (mutex) { return new SynchronizedNavigableMap<>(nm.headMap(toKey, inclusive), mutex); } }
        public NavigableMap<K, V> tailMap(K fromKey, boolean inclusive) { synchronized (mutex) { return new SynchronizedNavigableMap<>(nm.tailMap(fromKey, inclusive), mutex); } }
    }

    // ----- collections vides, singletons --------------------------------------
    public static <T> Iterator<T> emptyIterator() { return (Iterator<T>) EmptyIterator.EMPTY_ITERATOR; }
    private static class EmptyIterator<E> implements Iterator<E> {
        static final EmptyIterator<Object> EMPTY_ITERATOR = new EmptyIterator<>();
        public boolean hasNext() { return false; }
        public E next() { throw new NoSuchElementException(); }
        public void remove() { throw new IllegalStateException(); }
        public void forEachRemaining(Consumer<? super E> action) { Objects.requireNonNull(action); }
    }
    public static <T> ListIterator<T> emptyListIterator() { return (ListIterator<T>) EmptyListIterator.EMPTY_ITERATOR; }
    private static class EmptyListIterator<E> extends EmptyIterator<E> implements ListIterator<E> {
        static final EmptyListIterator<Object> EMPTY_ITERATOR = new EmptyListIterator<>();
        public boolean hasPrevious() { return false; }
        public E previous() { throw new NoSuchElementException(); }
        public int nextIndex() { return 0; }
        public int previousIndex() { return -1; }
        public void set(E e) { throw new IllegalStateException(); }
        public void add(E e) { throw new UnsupportedOperationException(); }
    }
    public static <T> Enumeration<T> emptyEnumeration() { return (Enumeration<T>) EmptyEnumeration.EMPTY_ENUMERATION; }
    private static class EmptyEnumeration<E> implements Enumeration<E> {
        static final EmptyEnumeration<Object> EMPTY_ENUMERATION = new EmptyEnumeration<>();
        public boolean hasMoreElements() { return false; }
        public E nextElement() { throw new NoSuchElementException(); }
    }
    public static final <T> Set<T> emptySet() { return (Set<T>) EMPTY_SET; }
    private static class EmptySet<E> extends AbstractSet<E> implements java.io.Serializable {
    private static final long serialVersionUID = 1582296315990362920L;
        public Iterator<E> iterator() { return emptyIterator(); }
        public int size() { return 0; }
        public boolean isEmpty() { return true; }
        public void clear() { }
        public boolean contains(Object obj) { return false; }
        public boolean containsAll(Collection<?> c) { return c.isEmpty(); }
        public Object[] toArray() { return new Object[0]; }
        public <T> T[] toArray(T[] a) { if (a.length > 0) a[0] = null; return a; }
        public void forEach(Consumer<? super E> action) { Objects.requireNonNull(action); }
        public boolean removeIf(Predicate<? super E> filter) { Objects.requireNonNull(filter); return false; }
        public int hashCode() { return 0; }
        private Object readResolve() { return EMPTY_SET; }
    }
    public static <E> SortedSet<E> emptySortedSet() { return (SortedSet<E>) new TreeSet<E>(); }
    public static <E> NavigableSet<E> emptyNavigableSet() { return (NavigableSet<E>) unmodifiableNavigableSet(new TreeSet<E>()); }
    public static final <T> List<T> emptyList() { return (List<T>) EMPTY_LIST; }
    private static class EmptyList<E> extends AbstractList<E> implements RandomAccess, java.io.Serializable {
    private static final long serialVersionUID = 8842843931221139166L;
        public Iterator<E> iterator() { return emptyIterator(); }
        public ListIterator<E> listIterator() { return emptyListIterator(); }
        public int size() { return 0; }
        public boolean isEmpty() { return true; }
        public void clear() { }
        public boolean contains(Object obj) { return false; }
        public boolean containsAll(Collection<?> c) { return c.isEmpty(); }
        public Object[] toArray() { return new Object[0]; }
        public <T> T[] toArray(T[] a) { if (a.length > 0) a[0] = null; return a; }
        public E get(int index) { throw new IndexOutOfBoundsException("Index: " + index); }
        public boolean equals(Object o) { return (o instanceof List) && ((List<?>) o).isEmpty(); }
        public int hashCode() { return 1; }
        public boolean removeIf(Predicate<? super E> filter) { Objects.requireNonNull(filter); return false; }
        public void replaceAll(UnaryOperator<E> operator) { Objects.requireNonNull(operator); }
        public void sort(Comparator<? super E> c) { }
        public void forEach(Consumer<? super E> action) { Objects.requireNonNull(action); }
        private Object readResolve() { return EMPTY_LIST; }
    }
    public static final <K, V> Map<K, V> emptyMap() { return (Map<K, V>) EMPTY_MAP; }
    public static final <K, V> SortedMap<K, V> emptySortedMap() { return new TreeMap<K, V>(); }
    public static final <K, V> NavigableMap<K, V> emptyNavigableMap() { return unmodifiableNavigableMap(new TreeMap<K, V>()); }
    private static class EmptyMap<K, V> extends AbstractMap<K, V> implements java.io.Serializable {
    private static final long serialVersionUID = 6428348081105594320L;
        public int size() { return 0; }
        public boolean isEmpty() { return true; }
        public void clear() { }
        public boolean containsKey(Object key) { return false; }
        public boolean containsValue(Object value) { return false; }
        public V get(Object key) { return null; }
        public Set<K> keySet() { return emptySet(); }
        public Collection<V> values() { return emptySet(); }
        public Set<Map.Entry<K, V>> entrySet() { return emptySet(); }
        public boolean equals(Object o) { return (o instanceof Map) && ((Map<?, ?>) o).isEmpty(); }
        public int hashCode() { return 0; }
        public V getOrDefault(Object k, V defaultValue) { return defaultValue; }
        public void forEach(BiConsumer<? super K, ? super V> action) { Objects.requireNonNull(action); }
        public void replaceAll(BiFunction<? super K, ? super V, ? extends V> function) { Objects.requireNonNull(function); }
        public V putIfAbsent(K key, V value) { throw new UnsupportedOperationException(); }
        public boolean remove(Object key, Object value) { throw new UnsupportedOperationException(); }
        public boolean replace(K key, V oldValue, V newValue) { throw new UnsupportedOperationException(); }
        public V replace(K key, V value) { throw new UnsupportedOperationException(); }
        public V computeIfAbsent(K key, Function<? super K, ? extends V> mappingFunction) { throw new UnsupportedOperationException(); }
        public V computeIfPresent(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        public V compute(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        public V merge(K key, V value, BiFunction<? super V, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        private Object readResolve() { return EMPTY_MAP; }
    }
    public static <T> Set<T> singleton(T o) { return new SingletonSet<>(o); }
    static <E> Iterator<E> singletonIterator(final E e) {
        return new Iterator<E>() {
            private boolean hasNext = true;
            public boolean hasNext() { return hasNext; }
            public E next() { if (hasNext) { hasNext = false; return e; } throw new NoSuchElementException(); }
            public void remove() { throw new UnsupportedOperationException(); }
            public void forEachRemaining(Consumer<? super E> action) { Objects.requireNonNull(action); if (hasNext) { hasNext = false; action.accept(e); } }
        };
    }
    private static class SingletonSet<E> extends AbstractSet<E> implements java.io.Serializable {
    private static final long serialVersionUID = 3193687207550431679L;
        private final E element;
        SingletonSet(E e) { element = e; }
        public Iterator<E> iterator() { return singletonIterator(element); }
        public int size() { return 1; }
        public boolean contains(Object o) { return Objects.equals(o, element); }
        public void forEach(Consumer<? super E> action) { action.accept(element); }
        public boolean removeIf(Predicate<? super E> filter) { throw new UnsupportedOperationException(); }
        public int hashCode() { return Objects.hashCode(element); }
    }
    public static <T> List<T> singletonList(T o) { return new SingletonList<>(o); }
    private static class SingletonList<E> extends AbstractList<E> implements RandomAccess, java.io.Serializable {
    private static final long serialVersionUID = 3093736618740652951L;
        private final E element;
        SingletonList(E obj) { element = obj; }
        public Iterator<E> iterator() { return singletonIterator(element); }
        public int size() { return 1; }
        public boolean contains(Object obj) { return Objects.equals(obj, element); }
        public E get(int index) { if (index != 0) throw new IndexOutOfBoundsException("Index: " + index + ", Size: 1"); return element; }
        public void forEach(Consumer<? super E> action) { action.accept(element); }
        public boolean removeIf(Predicate<? super E> filter) { throw new UnsupportedOperationException(); }
        public void replaceAll(UnaryOperator<E> operator) { throw new UnsupportedOperationException(); }
        public void sort(Comparator<? super E> c) { }
        public int hashCode() { return 31 + Objects.hashCode(element); }
    }
    public static <K, V> Map<K, V> singletonMap(K key, V value) { return new SingletonMap<>(key, value); }
    private static class SingletonMap<K, V> extends AbstractMap<K, V> implements java.io.Serializable {
    private static final long serialVersionUID = -6979724477215052911L;
        private final K k;
        private final V v;
        SingletonMap(K key, V value) { k = key; v = value; }
        public int size() { return 1; }
        public boolean isEmpty() { return false; }
        public boolean containsKey(Object key) { return Objects.equals(key, k); }
        public boolean containsValue(Object value) { return Objects.equals(value, v); }
        public V get(Object key) { return (Objects.equals(key, k) ? v : null); }
        private transient Set<K> keySet;
        private transient Set<Map.Entry<K, V>> entrySet;
        private transient Collection<V> values;
        public Set<K> keySet() { if (keySet == null) keySet = singleton(k); return keySet; }
        public Set<Map.Entry<K, V>> entrySet() { if (entrySet == null) entrySet = Collections.<Map.Entry<K, V>>singleton(new SimpleImmutableEntry<>(k, v)); return entrySet; }
        public Collection<V> values() { if (values == null) values = singleton(v); return values; }
        public V getOrDefault(Object key, V defaultValue) { return Objects.equals(key, k) ? v : defaultValue; }
        public void forEach(BiConsumer<? super K, ? super V> action) { action.accept(k, v); }
        public void replaceAll(BiFunction<? super K, ? super V, ? extends V> function) { throw new UnsupportedOperationException(); }
        public V putIfAbsent(K key, V value) { throw new UnsupportedOperationException(); }
        public boolean remove(Object key, Object value) { throw new UnsupportedOperationException(); }
        public boolean replace(K key, V oldValue, V newValue) { throw new UnsupportedOperationException(); }
        public V replace(K key, V value) { throw new UnsupportedOperationException(); }
        public V computeIfAbsent(K key, Function<? super K, ? extends V> mappingFunction) { throw new UnsupportedOperationException(); }
        public V computeIfPresent(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        public V compute(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        public V merge(K key, V value, BiFunction<? super V, ? super V, ? extends V> remappingFunction) { throw new UnsupportedOperationException(); }
        public int hashCode() { return Objects.hashCode(k) ^ Objects.hashCode(v); }
    }
    public static <T> List<T> nCopies(int n, T o) {
        if (n < 0) throw new IllegalArgumentException("List length = " + n);
        return new CopiesList<>(n, o);
    }
    private static class CopiesList<E> extends AbstractList<E> implements RandomAccess, java.io.Serializable {
    private static final long serialVersionUID = 2739099268398711800L;
        final int n;
        final E element;
        CopiesList(int n, E e) { this.n = n; element = e; }
        public int size() { return n; }
        public boolean contains(Object obj) { return n != 0 && Objects.equals(obj, element); }
        public int indexOf(Object o) { return contains(o) ? 0 : -1; }
        public int lastIndexOf(Object o) { return contains(o) ? n - 1 : -1; }
        public E get(int index) { if (index < 0 || index >= n) throw new IndexOutOfBoundsException("Index: " + index + ", Size: " + n); return element; }
        public Object[] toArray() { Object[] a = new Object[n]; if (element != null) Arrays.fill(a, 0, n, element); return a; }
        public <T> T[] toArray(T[] a) {
            final int n = this.n;
            if (a.length < n) { a = (T[]) java.lang.reflect.Array.newInstance(a.getClass().getComponentType(), n); if (element != null) Arrays.fill(a, 0, n, element); }
            else { Arrays.fill(a, 0, n, element); if (a.length > n) a[n] = null; }
            return a;
        }
        public List<E> subList(int fromIndex, int toIndex) {
            if (fromIndex < 0) throw new IndexOutOfBoundsException("fromIndex = " + fromIndex);
            if (toIndex > n) throw new IndexOutOfBoundsException("toIndex = " + toIndex);
            if (fromIndex > toIndex) throw new IllegalArgumentException("fromIndex(" + fromIndex + ") > toIndex(" + toIndex + ")");
            return new CopiesList<>(toIndex - fromIndex, element);
        }
        public int hashCode() {
            if (n == 0) return 1;
            int pow = 31, sum = 1;
            for (int i = Integer.numberOfLeadingZeros(n) + 1; i < Integer.SIZE; i++) {
                sum *= pow + 1;
                pow *= pow;
                if ((n << i) < 0) { pow *= 31; sum = sum * 31 + 1; }
            }
            return pow + sum * (element == null ? 0 : element.hashCode());
        }
        public boolean equals(Object o) {
            if (o == this) return true;
            if (o instanceof CopiesList<?> other) return n == other.n && (n == 0 || Objects.equals(element, other.element));
            if (!(o instanceof List<?> other)) return false;
            if (n != other.size()) return false;
            Iterator<?> itr = other.iterator();
            for (int i = 0; i < n; i++) if (!itr.hasNext() || !Objects.equals(element, itr.next())) return false;
            return !itr.hasNext();
        }
        public void forEach(Consumer<? super E> action) { Objects.requireNonNull(action); for (int i = 0; i < n; i++) action.accept(element); }
        public boolean removeIf(Predicate<? super E> filter) { throw new UnsupportedOperationException(); }
        public void replaceAll(UnaryOperator<E> operator) { throw new UnsupportedOperationException(); }
        public void sort(Comparator<? super E> c) { }
    }

    // ----- comparateurs ------------------------------------------------------------
    enum NaturalOrder implements Comparator<Comparable<Object>> {
        INSTANCE;
        public int compare(Comparable<Object> c1, Comparable<Object> c2) { return c1.compareTo(c2); }
        public Comparator<Comparable<Object>> reversed() { return Collections.reverseOrder(); }
    }
    public static <T> Comparator<T> reverseOrder() { return (Comparator<T>) ReverseComparator.REVERSE_ORDER; }
    private static class ReverseComparator implements Comparator<Comparable<Object>>, java.io.Serializable {
    private static final long serialVersionUID = 7207038068494060240L;
        static final ReverseComparator REVERSE_ORDER = new ReverseComparator();
        public int compare(Comparable<Object> c1, Comparable<Object> c2) { return c2.compareTo(c1); }
        private Object readResolve() { return Collections.reverseOrder(); }
        public Comparator<Comparable<Object>> reversed() { return Comparator.naturalOrder(); }
    }
    public static <T> Comparator<T> reverseOrder(Comparator<T> cmp) {
        if (cmp == null) return (Comparator<T>) ReverseComparator.REVERSE_ORDER;
        else if (cmp == ReverseComparator.REVERSE_ORDER) return (Comparator<T>) Comparator.naturalOrder();
        else if (cmp == Comparator.naturalOrder()) return (Comparator<T>) ReverseComparator.REVERSE_ORDER;
        else if (cmp instanceof ReverseComparator2) return ((ReverseComparator2<T>) cmp).cmp;
        else return new ReverseComparator2<>(cmp);
    }
    private static class ReverseComparator2<T> implements Comparator<T>, java.io.Serializable {
    private static final long serialVersionUID = 4374092139857L;
        final Comparator<T> cmp;
        ReverseComparator2(Comparator<T> cmp) { this.cmp = cmp; }
        public int compare(T t1, T t2) { return cmp.compare(t2, t1); }
        public boolean equals(Object o) { return (o == this) || (o instanceof ReverseComparator2 && cmp.equals(((ReverseComparator2) o).cmp)); }
        public int hashCode() { return cmp.hashCode() ^ Integer.MIN_VALUE; }
        public Comparator<T> reversed() { return cmp; }
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
        Collection<?> contains = c2;
        Collection<?> iterate = c1;
        if (c1 instanceof Set) { iterate = c2; contains = c1; }
        else if (!(c2 instanceof Set)) {
            int c1size = c1.size();
            int c2size = c2.size();
            if (c1size == 0 || c2size == 0) return true;
            if (c1size > c2size) { iterate = c2; contains = c1; }
        }
        for (Object e : iterate) if (contains.contains(e)) return false;
        return true;
    }
    public static <T> boolean addAll(Collection<? super T> c, T... elements) {
        boolean result = false;
        for (T element : elements) result |= c.add(element);
        return result;
    }
    public static int lastIndexOfSubList(List<?> source, List<?> target) {
        int sourceSize = source.size(), targetSize = target.size();
        int maxCandidate = sourceSize - targetSize;
        for (int candidate = maxCandidate; candidate >= 0; candidate--) {
            boolean ok = true;
            for (int i = 0; i < targetSize; i++) if (!Objects.equals(target.get(i), source.get(candidate + i))) { ok = false; break; }
            if (ok) return candidate;
        }
        return -1;
    }
    public static <E> Set<E> newSetFromMap(Map<E, Boolean> map) {
        if (!map.isEmpty()) throw new IllegalArgumentException("Map is non-empty");
        return new SetFromMap<>(map);
    }
    private static class SetFromMap<E> extends AbstractSet<E> implements Set<E>, java.io.Serializable {
    private static final long serialVersionUID = 2454657854757543876L;
        private final Map<E, Boolean> m;
        private transient Set<E> s;
        SetFromMap(Map<E, Boolean> map) { m = map; s = map.keySet(); }
        public void clear() { m.clear(); }
        public int size() { return m.size(); }
        public boolean isEmpty() { return m.isEmpty(); }
        public boolean contains(Object o) { return m.containsKey(o); }
        public boolean remove(Object o) { return m.remove(o) != null; }
        public boolean add(E e) { return m.put(e, Boolean.TRUE) == null; }
        public Iterator<E> iterator() { return s.iterator(); }
        public Object[] toArray() { return s.toArray(); }
        public <T> T[] toArray(T[] a) { return s.toArray(a); }
        public String toString() { return s.toString(); }
        public int hashCode() { return s.hashCode(); }
        public boolean equals(Object o) { return o == this || s.equals(o); }
        public boolean containsAll(Collection<?> c) { return s.containsAll(c); }
        public boolean removeAll(Collection<?> c) { return s.removeAll(c); }
        public boolean retainAll(Collection<?> c) { return s.retainAll(c); }
        public void forEach(Consumer<? super E> action) { s.forEach(action); }
        public boolean removeIf(Predicate<? super E> filter) { return s.removeIf(filter); }
        private void readObject(java.io.ObjectInputStream stream) throws java.io.IOException, ClassNotFoundException {
            stream.defaultReadObject();
            s = m.keySet();
        }
    }
    public static <T> Queue<T> asLifoQueue(Deque<T> deque) { return new AsLIFOQueue<>(Objects.requireNonNull(deque)); }
    static class AsLIFOQueue<E> extends AbstractQueue<E> implements Queue<E>, java.io.Serializable {
    private static final long serialVersionUID = 1802017725587941708L;
        private final Deque<E> q;
        AsLIFOQueue(Deque<E> q) { this.q = q; }
        public boolean add(E e) { q.addFirst(e); return true; }
        public boolean offer(E e) { return q.offerFirst(e); }
        public E poll() { return q.pollFirst(); }
        public E remove() { return q.removeFirst(); }
        public E peek() { return q.peekFirst(); }
        public E element() { return q.getFirst(); }
        public void clear() { q.clear(); }
        public int size() { return q.size(); }
        public boolean isEmpty() { return q.isEmpty(); }
        public boolean contains(Object o) { return q.contains(o); }
        public boolean remove(Object o) { return q.remove(o); }
        public Iterator<E> iterator() { return q.iterator(); }
        public Object[] toArray() { return q.toArray(); }
        public <T> T[] toArray(T[] a) { return q.toArray(a); }
        public String toString() { return q.toString(); }
        public boolean containsAll(Collection<?> c) { return q.containsAll(c); }
        public boolean removeAll(Collection<?> c) { return q.removeAll(c); }
        public boolean retainAll(Collection<?> c) { return q.retainAll(c); }
        public void forEach(Consumer<? super E> action) { q.forEach(action); }
        public boolean removeIf(Predicate<? super E> filter) { return q.removeIf(filter); }
    }
}
