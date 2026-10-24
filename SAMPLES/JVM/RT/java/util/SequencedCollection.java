package java.util;
public interface SequencedCollection<E> extends Collection<E> {
    default void addFirst(E e) { throw new UnsupportedOperationException(); }
    default void addLast(E e) { throw new UnsupportedOperationException(); }
    default E getFirst() { return this.iterator().next(); }
    default E getLast() { throw new UnsupportedOperationException(); }
    default E removeFirst() { Iterator<E> it = this.iterator(); E e = it.next(); it.remove(); return e; }
    default E removeLast() { throw new UnsupportedOperationException(); }
}
