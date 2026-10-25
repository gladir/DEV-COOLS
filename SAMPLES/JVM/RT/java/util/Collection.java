package java.util;
import java.util.function.*;
import java.util.stream.Stream;
public interface Collection<E> extends Iterable<E> {
    int size();
    boolean isEmpty();
    boolean contains(Object o);
    Iterator<E> iterator();
    Object[] toArray();
    <T> T[] toArray(T[] a);
    default <T> T[] toArray(IntFunction<T[]> generator) { return toArray(generator.apply(0)); }
    boolean add(E e);
    boolean remove(Object o);
    boolean containsAll(Collection<?> c);
    boolean addAll(Collection<? extends E> c);
    boolean removeAll(Collection<?> c);
    default boolean removeIf(Predicate<? super E> filter) {
        boolean removed = false;
        Iterator<E> each = iterator();
        while (each.hasNext()) { if (filter.test(each.next())) { each.remove(); removed = true; } }
        return removed;
    }
    boolean retainAll(Collection<?> c);
    void clear();
    boolean equals(Object o);
    int hashCode();
    default Stream<E> stream() { return new java.util.stream.StreamImpl<E>(iterator()); }
    default Stream<E> parallelStream() { return stream(); }
}
