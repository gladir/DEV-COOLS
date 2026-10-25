package java.util;
public interface Enumeration<E> {
    boolean hasMoreElements();
    E nextElement();
    default Iterator<E> asIterator() {
        return new Iterator<E>() {
            public boolean hasNext() { return hasMoreElements(); }
            public E next() { return nextElement(); }
        };
    }
}
