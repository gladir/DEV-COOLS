package java.util;
public interface Set<E> extends Collection<E> {
    int size();
    boolean isEmpty();
    boolean contains(Object o);
    Iterator<E> iterator();
    Object[] toArray();
    <T> T[] toArray(T[] a);
    boolean add(E e);
    boolean remove(Object o);
    boolean containsAll(Collection<?> c);
    boolean addAll(Collection<? extends E> c);
    boolean retainAll(Collection<?> c);
    boolean removeAll(Collection<?> c);
    void clear();
    boolean equals(Object o);
    int hashCode();
    static <E> Set<E> of() { return ImmutableCollections.setOf(); }
    static <E> Set<E> of(E e1) { return ImmutableCollections.setOf(e1); }
    static <E> Set<E> of(E e1, E e2) { return ImmutableCollections.setOf(e1, e2); }
    static <E> Set<E> of(E e1, E e2, E e3) { return ImmutableCollections.setOf(e1, e2, e3); }
    static <E> Set<E> of(E e1, E e2, E e3, E e4) { return ImmutableCollections.setOf(e1, e2, e3, e4); }
    static <E> Set<E> of(E e1, E e2, E e3, E e4, E e5) { return ImmutableCollections.setOf(e1, e2, e3, e4, e5); }
    static <E> Set<E> of(E e1, E e2, E e3, E e4, E e5, E e6) { return ImmutableCollections.setOf(e1, e2, e3, e4, e5, e6); }
    static <E> Set<E> of(E e1, E e2, E e3, E e4, E e5, E e6, E e7) { return ImmutableCollections.setOf(e1, e2, e3, e4, e5, e6, e7); }
    static <E> Set<E> of(E... elements) { return ImmutableCollections.setOf(elements); }
    static <E> Set<E> copyOf(Collection<? extends E> coll) { return ImmutableCollections.setOf(new LinkedHashSet<E>(coll).toArray()); }
}
