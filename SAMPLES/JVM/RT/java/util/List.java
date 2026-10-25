package java.util;
import java.util.function.UnaryOperator;
public interface List<E> extends Collection<E> {
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
    boolean addAll(int index, Collection<? extends E> c);
    boolean removeAll(Collection<?> c);
    boolean retainAll(Collection<?> c);
    default void replaceAll(UnaryOperator<E> operator) {
        ListIterator<E> li = this.listIterator();
        while (li.hasNext()) li.set(operator.apply(li.next()));
    }
    default void sort(Comparator<? super E> c) {
        Object[] a = this.toArray();
        Arrays.sort(a, (Comparator) c);
        ListIterator<E> i = this.listIterator();
        for (Object e : a) { i.next(); i.set((E) e); }
    }
    void clear();
    boolean equals(Object o);
    int hashCode();
    E get(int index);
    E set(int index, E element);
    void add(int index, E element);
    E remove(int index);
    int indexOf(Object o);
    int lastIndexOf(Object o);
    ListIterator<E> listIterator();
    ListIterator<E> listIterator(int index);
    List<E> subList(int fromIndex, int toIndex);
    default void addFirst(E e) { this.add(0, e); }
    default void addLast(E e) { this.add(e); }
    default E getFirst() { if (this.isEmpty()) throw new NoSuchElementException(); return this.get(0); }
    default E getLast() { if (this.isEmpty()) throw new NoSuchElementException(); return this.get(this.size() - 1); }
    default E removeFirst() { if (this.isEmpty()) throw new NoSuchElementException(); return this.remove(0); }
    default E removeLast() { if (this.isEmpty()) throw new NoSuchElementException(); return this.remove(this.size() - 1); }
    default List<E> reversed() { ArrayList<E> r = new ArrayList<>(this); Collections.reverse(r); return r; }
    static <E> List<E> of() { return ImmutableCollections.listOf(); }
    static <E> List<E> of(E e1) { return ImmutableCollections.listOf(e1); }
    static <E> List<E> of(E e1, E e2) { return ImmutableCollections.listOf(e1, e2); }
    static <E> List<E> of(E e1, E e2, E e3) { return ImmutableCollections.listOf(e1, e2, e3); }
    static <E> List<E> of(E e1, E e2, E e3, E e4) { return ImmutableCollections.listOf(e1, e2, e3, e4); }
    static <E> List<E> of(E e1, E e2, E e3, E e4, E e5) { return ImmutableCollections.listOf(e1, e2, e3, e4, e5); }
    static <E> List<E> of(E e1, E e2, E e3, E e4, E e5, E e6) { return ImmutableCollections.listOf(e1, e2, e3, e4, e5, e6); }
    static <E> List<E> of(E e1, E e2, E e3, E e4, E e5, E e6, E e7) { return ImmutableCollections.listOf(e1, e2, e3, e4, e5, e6, e7); }
    static <E> List<E> of(E e1, E e2, E e3, E e4, E e5, E e6, E e7, E e8) { return ImmutableCollections.listOf(e1, e2, e3, e4, e5, e6, e7, e8); }
    static <E> List<E> of(E e1, E e2, E e3, E e4, E e5, E e6, E e7, E e8, E e9) { return ImmutableCollections.listOf(e1, e2, e3, e4, e5, e6, e7, e8, e9); }
    static <E> List<E> of(E e1, E e2, E e3, E e4, E e5, E e6, E e7, E e8, E e9, E e10) { return ImmutableCollections.listOf(e1, e2, e3, e4, e5, e6, e7, e8, e9, e10); }
    static <E> List<E> of(E... elements) { return ImmutableCollections.listOf(elements); }
    static <E> List<E> copyOf(Collection<? extends E> coll) {
        if (coll instanceof ImmutableCollections.ImmList) return (List<E>) coll;
        return (List<E>) ImmutableCollections.listOf(coll.toArray());
    }
}
